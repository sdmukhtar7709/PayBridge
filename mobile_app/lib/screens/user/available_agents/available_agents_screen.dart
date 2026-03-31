import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../config/api_config.dart';
import '../../../services/auth_service.dart';
import '../../../services/agent_rating_live_store.dart';
import '../../../services/available_agents_context_store.dart';
import '../../../services/local_notification_service.dart';
import '../../../services/location_service.dart';
import '../../../services/request_type_store.dart';
import '../transactions/transaction_success_screen.dart';

part 'available_agents_models.dart';
part 'available_agents_widgets.dart';

/// Screen that displays agents available near a given city / coordinates.
/// Opened from UPI-to-Cash and Cash-to-UPI screens after the user taps
/// "Check Availability".
class AvailableAgentsScreen extends StatefulWidget {
  final String city;
  final double? latitude;
  final double? longitude;
  final double radiusKm;
  final String transactionType; // e.g. 'UPI -> Cash' or 'Cash -> UPI'
  final String amount;

  const AvailableAgentsScreen({
    super.key,
    required this.city,
    this.latitude,
    this.longitude,
    required this.radiusKm,
    required this.transactionType,
    required this.amount,
  });

  @override
  State<AvailableAgentsScreen> createState() => _AvailableAgentsScreenState();
}

class _AvailableAgentsScreenState extends State<AvailableAgentsScreen> {
  static final String _apiBaseUrl = ApiConfig.baseUrl;

  List<_AgentSummary> _agents = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _requestingAgentId;
  final Map<String, _RequestState> _requestByAgentId = {};
  final Set<String> _shownSuccessTxnIds = <String>{};
  Timer? _statusPollTimer;
  StreamSubscription<AgentRatingLiveUpdate>? _ratingLiveSub;
  String? _archivingTransactionId;
  bool _isClearingAll = false;
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    AvailableAgentsContextStore.save(
      AvailableAgentsContext(
        city: widget.city,
        latitude: widget.latitude,
        longitude: widget.longitude,
        radiusKm: widget.radiusKm,
        transactionType: widget.transactionType,
        amount: widget.amount,
      ),
    );
    _ratingLiveSub = AgentRatingLiveStore.instance.stream.listen((update) {
      if (!mounted) return;
      final next = _agents.map((agent) {
        if (agent.id != update.agentId) return agent;
        final nextCount = update.ratingCount;
        final nextSum = (update.averageRating * nextCount).round();
        return agent.copyWith(ratingSum: nextSum, ratingCount: nextCount);
      }).toList();
      setState(() => _agents = next);
    });
    _fetchAgents();
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    _ratingLiveSub?.cancel();
    super.dispose();
  }

  void _ensurePolling() {
    if (_statusPollTimer != null) return;
    _pollRequestStatuses();
    _statusPollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _pollRequestStatuses();
    });
  }
  void _stopPollingIfIdle() {
    final hasPending = _requestByAgentId.values.any(
      (state) => state.status == 'pending' || state.status == 'approved',
    );
    if (!hasPending) {
      _statusPollTimer?.cancel();
      _statusPollTimer = null;
    }
  }

  Future<void> _pollRequestStatuses() async {
    final pendingEntries = _requestByAgentId.entries
        .where(
          (entry) =>
              entry.value.status == 'pending' ||
              entry.value.status == 'approved',
        )
        .toList();
    if (pendingEntries.isEmpty) {
      _stopPollingIfIdle();
      return;
    }

    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return;

    bool changed = false;
    for (final entry in pendingEntries) {
      final state = entry.value;
      try {
        final response = await http.get(
          Uri.parse(
            '$_apiBaseUrl/transactions/request/${state.transactionId}/status',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        final body = _decodeBody(response);
        if (response.statusCode == 404) {
          _requestByAgentId.remove(entry.key);
          changed = true;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Request cleared from the list.')),
            );
          }
          continue;
        }
        if (response.statusCode < 200 || response.statusCode >= 300) continue;

        final latestStatus = (body['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final requestOtp = (body['requestOtp'] ?? '').toString().trim();
        final userConfirmOtp = (body['userConfirmOtp'] ?? '').toString().trim();
        final approvedAt = DateTime.tryParse(
          (body['approvedAt'] ?? '').toString(),
        );
        final userConfirmedAt = DateTime.tryParse(
          (body['userConfirmedAt'] ?? '').toString(),
        );
        final agentConfirmedAt = DateTime.tryParse(
          (body['agentConfirmedAt'] ?? '').toString(),
        );

        if (latestStatus.isEmpty) continue;

        if (latestStatus == 'pending') {
          _requestByAgentId[entry.key] = state.copyWith(
            status: 'pending',
            requestOtp: requestOtp,
            userConfirmOtp: userConfirmOtp,
            approvedAt: approvedAt,
            userConfirmedAt: userConfirmedAt,
            agentConfirmedAt: agentConfirmedAt,
          );
          changed = true;
          continue;
        }

        if (latestStatus == 'rejected') {
          _requestByAgentId[entry.key] = state.copyWith(
            status: 'rejected',
            rejectionNotified: true,
          );
          changed = true;
          if (mounted && !state.rejectionNotified) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Rejected, try another agent')),
            );
            LocalNotificationService.instance.showUserStatusNotification(
              title: 'Request Rejected',
              message: 'Agent rejected your request. Try another agent.',
              payload: 'user_request:${state.transactionId}',
            );
          }
        } else if (latestStatus == 'approved') {
          final becameFirstOtpVerified =
              state.approvedAt == null && approvedAt != null;
          final becameApproved = state.status != 'approved';
          final shouldNotifyApproved =
              becameApproved && !state.approvedNotified;
          final shouldShowFirstOtpPopup =
              becameFirstOtpVerified && !state.approvedNotified;

          _requestByAgentId[entry.key] = state.copyWith(
            status: 'approved',
            requestOtp: requestOtp,
            userConfirmOtp: userConfirmOtp,
            approvedAt: approvedAt,
            userConfirmedAt: userConfirmedAt,
            agentConfirmedAt: agentConfirmedAt,
            approvedNotified:
                state.approvedNotified ||
                becameFirstOtpVerified ||
                becameApproved,
          );
          changed = true;
          if (mounted && shouldNotifyApproved) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Agent approved your request. Please see details.',
                ),
              ),
            );
            LocalNotificationService.instance.showUserStatusNotification(
              title: 'Request Approved',
              message: 'Agent approved your request. Please see details.',
              payload: 'user_approved:${state.transactionId}',
            );
          }
          if (mounted && shouldShowFirstOtpPopup) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'First OTP verified. OTP is ready for transaction.',
                ),
              ),
            );
            LocalNotificationService.instance.showUserStatusNotification(
              title: 'OTP Ready',
              message:
                  'Your OTP is ready. Complete the transaction with the agent.',
              payload: 'user_request:${state.transactionId}',
            );
            final otpText = userConfirmOtp.isNotEmpty
                ? userConfirmOtp
                : 'Pending';
            await _showSimpleDialog(
              title: 'OTP Ready',
              message: 'Your OTP: $otpText',
              icon: Icons.check_circle,
              iconColor: const Color(0xff059669),
              iconBg: const Color(0xffECFDF3),
            );
          }
        } else if (latestStatus == 'confirmed') {
          final transactionId = state.transactionId;
          final agentBody = body['agent'] is Map<String, dynamic>
              ? body['agent'] as Map<String, dynamic>
              : <String, dynamic>{};
          final agentUser = agentBody['user'] is Map<String, dynamic>
              ? agentBody['user'] as Map<String, dynamic>
              : <String, dynamic>{};

          if (mounted && !_shownSuccessTxnIds.contains(transactionId)) {
            _shownSuccessTxnIds.add(transactionId);
            LocalNotificationService.instance.showUserStatusNotification(
              title: 'Transaction Completed',
              message: 'Your transaction is completed successfully.',
              payload: 'user_request:$transactionId',
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TransactionSuccessScreen(
                    amount: widget.amount,
                    agentName: (agentUser['name'] ?? 'Agent').toString(),
                    agentPhone: (agentUser['phone'] ?? '').toString(),
                    city: (agentBody['city'] ?? '').toString(),
                    shopName: (agentBody['locationName'] ?? '').toString(),
                    transactionId: transactionId,
                  ),
                ),
              );
            });
          }

          _requestByAgentId.remove(entry.key);
          changed = true;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Transaction verified successfully.'),
              ),
            );
          }
        } else {
          _requestByAgentId.remove(entry.key);
          changed = true;
        }
      } catch (_) {
        // ignore polling errors
      }
    }

    if (mounted && changed) {
      setState(() {});
    }
    _stopPollingIfIdle();
  }

  Future<void> _archiveRequestByTransactionId(
    String agentId,
    String transactionId,
  ) async {
    if (_archivingTransactionId != null) return;

    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return;

    setState(() => _archivingTransactionId = transactionId);
    try {
      final response = await http.patch(
        Uri.parse('$_apiBaseUrl/transactions/requests/$transactionId/archive'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final body = _decodeBody(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 404) {
          if (!mounted) return;
          setState(() => _requestByAgentId.remove(agentId));
          await RequestTypeStore.removeType(transactionId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request cleared from the list.')),
          );
          return;
        }
        throw Exception(_readError(body, 'Failed to clear request'));
      }

      if (!mounted) return;
      setState(() => _requestByAgentId.remove(agentId));
      await RequestTypeStore.removeType(transactionId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request cleared from the list.')),
      );
      _stopPollingIfIdle();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _archivingTransactionId = null);
    }
  }

  Future<void> _confirmClearRequest(String agentId, _RequestState state) async {
    final shouldClear = await _showConfirmDialog(
      title: 'Clear this request?',
      message: 'This will remove the request from the list.',
      primaryLabel: 'Clear',
    );

    if (shouldClear == true) {
      await _archiveRequestByTransactionId(agentId, state.transactionId);
    }
  }

  Future<void> _clearAllRequests() async {
    if (_isClearingAll || _requestByAgentId.isEmpty) return;

    final shouldClear = await _showConfirmDialog(
      title: 'Clear all requests?',
      message: 'This will remove all your requests from this list.',
      primaryLabel: 'Clear All',
    );

    if (shouldClear != true) return;

    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return;

    setState(() => _isClearingAll = true);
    try {
      final response = await http.delete(
        Uri.parse('$_apiBaseUrl/transactions/requests/clear-all'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final body = _decodeBody(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = _readError(body, 'Failed to clear requests');
        if (message.toLowerCase().contains('not found')) {
          final entries = _requestByAgentId.entries.toList();
          for (final entry in entries) {
            final state = entry.value;
            try {
              if (state.status == 'pending') {
                await http.patch(
                  Uri.parse(
                    '$_apiBaseUrl/transactions/request/${state.transactionId}/cancel',
                  ),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                );
              } else {
                await http.patch(
                  Uri.parse(
                    '$_apiBaseUrl/transactions/requests/${state.transactionId}/archive',
                  ),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                );
              }
            } catch (_) {}
            await RequestTypeStore.removeType(state.transactionId);
          }

          if (!mounted) return;
          setState(() => _requestByAgentId.clear());
          _stopPollingIfIdle();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All requests cleared.')),
          );
          return;
        }
        throw Exception(message);
      }

      final entries = _requestByAgentId.values.toList();
      for (final state in entries) {
        await RequestTypeStore.removeType(state.transactionId);
      }

      if (!mounted) return;
      setState(() => _requestByAgentId.clear());
      _stopPollingIfIdle();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All requests cleared.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _isClearingAll = false);
    }
  }

  Future<void> _cancelRequest(_AgentSummary agent) async {
    final state = _requestByAgentId[agent.id];
    if (state == null || state.status != 'pending') return;

    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return;

    try {
      final response = await http.patch(
        Uri.parse(
          '$_apiBaseUrl/transactions/request/${state.transactionId}/cancel',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final body = _decodeBody(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;
        setState(() => _requestByAgentId.remove(agent.id));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Request cancelled')));
        LocalNotificationService.instance.showUserStatusNotification(
          title: 'Request Cancelled',
          message: 'Your request has been cancelled.',
          payload: 'user_request:${state.transactionId}',
        );
        _stopPollingIfIdle();
        return;
      }

      throw Exception(_readError(body, 'Failed to cancel request'));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _sendRequest(_AgentSummary agent) async {
    if (_requestingAgentId != null) return;

    if (!agent.isVerified) {
      if (!mounted) return;
      await _showSimpleDialog(
        title: 'Agent not verified',
        message:
            'This agent is not verified yet. Please choose another agent.',
      );
      return;
    }

    if (agent.isBanned) {
      if (!mounted) return;
      await _showSimpleDialog(
        title: 'Agent unavailable',
        message: 'This agent is currently unavailable.',
        icon: Icons.block,
        iconColor: const Color(0xffDC2626),
        iconBg: const Color(0xffFEE2E2),
      );
      return;
    }

    if (!agent.available) {
      if (!mounted) return;
      await _showSimpleDialog(
        title: 'Agent offline',
        message: 'This agent is currently offline. Please try another agent.',
      );
      return;
    }

    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login as user first')),
      );
      return;
    }

    final raw = widget.amount.replaceAll(RegExp(r'[^0-9.]'), '');
    final parsed = num.tryParse(raw);
    final amount = parsed?.round();
    if (amount == null || amount < 100) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be at least 100')),
      );
      return;
    }

    setState(() => _requestingAgentId = agent.id);
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/transactions/request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'agentId': agent.id, 'amount': amount}),
      );

      final body = _decodeBody(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final transactionId = (body['id'] ?? '').toString();
        await RequestTypeStore.saveType(
          transactionId: transactionId,
          requestType: widget.transactionType,
        );
        if (!mounted) return;
        setState(() {
          _requestByAgentId[agent.id] = _RequestState(
            transactionId: transactionId,
            status: 'pending',
          );
        });
        _ensurePolling();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request sent to ${agent.name}')),
        );
        return;
      }

      throw Exception(_readError(body, 'Failed to send request'));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _requestingAgentId = null);
    }
  }

  Future<void> _openDirections(_AgentSummary agent) async {
    AppLocation? userLocation;
    try {
      userLocation = await _locationService.getCurrentLocation();
    } catch (_) {
      // If location is unavailable, fallback to destination-only directions.
    }

    final destinationQuery = [
      if (agent.address.isNotEmpty) agent.address,
      if (agent.city.isNotEmpty) agent.city,
      if (agent.locationName.isNotEmpty) agent.locationName,
    ].join(', ');

    final destinationLat = agent.latitude;
    final destinationLng = agent.longitude;
    final originParam = userLocation != null
        ? '${userLocation.latitude},${userLocation.longitude}'
        : null;

    final Uri uri = (destinationLat != null && destinationLng != null)
        ? Uri.https('www.google.com', '/maps/dir/', {
            'api': '1',
            'destination': '$destinationLat,$destinationLng',
            if (originParam != null) 'origin': originParam,
          })
        : Uri.https('www.google.com', '/maps/search/', {
            'api': '1',
            'query': destinationQuery.isEmpty ? widget.city : destinationQuery,
            if (originParam != null) 'origin': originParam,
          });

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open directions right now')),
      );
    }
  }

  Future<void> _showConfirmAgentOtpDialog(
    String agentId,
    _RequestState state,
  ) async {
    if (state.userConfirmedAt != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agent OTP already verified.')),
        );
      }
      return;
    }

    String otpValue = '';
    String? inlineError;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            void safeSetState(VoidCallback update) {
              if (dialogContext.mounted) {
                setLocalState(update);
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter OTP',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      enabled: !isSubmitting && state.userConfirmedAt == null,
                      onChanged: (value) => otpValue = value.trim(),
                      decoration: InputDecoration(
                        hintText: '----',
                        counterText: '',
                        errorText: inlineError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: const Color(0xffFAFAFA),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Close'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSubmitting || state.userConfirmedAt != null
                                ? null
                                : () async {
                          final otp = otpValue.trim();
                          if (otp.length != 4) {
                            safeSetState(
                              () => inlineError = 'Enter a valid 4-digit OTP',
                            );
                            return;
                          }

                          final token = await AuthService.getToken();
                          if (token == null || token.isEmpty) {
                            safeSetState(
                              () => inlineError = 'Please login again',
                            );
                            return;
                          }

                          safeSetState(() {
                            inlineError = null;
                            isSubmitting = true;
                          });

                          try {
                            final response = await http.post(
                              Uri.parse(
                                '$_apiBaseUrl/transactions/confirm-user',
                              ),
                              headers: {
                                'Content-Type': 'application/json',
                                'Authorization': 'Bearer $token',
                              },
                              body: jsonEncode({
                                'transactionId': state.transactionId,
                                'otp': otp,
                              }),
                            );

                            final body = _decodeBody(response);
                            if (response.statusCode >= 200 &&
                                response.statusCode < 300) {
                              final status = (body['status'] ?? '')
                                  .toString()
                                  .trim()
                                  .toLowerCase();
                              if (!mounted) return;
                              setState(() {
                                final existing = _requestByAgentId[agentId];
                                if (existing != null) {
                                  _requestByAgentId[agentId] = existing
                                      .copyWith(
                                        userConfirmedAt: DateTime.now(),
                                      );
                                }
                              });
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                              if (mounted) {
                                if (status == 'confirmed') {
                                  final matchedAgent = _agents
                                      .where((item) => item.id == agentId)
                                      .cast<_AgentSummary?>()
                                      .firstWhere(
                                        (item) => item != null,
                                        orElse: () => null,
                                      );

                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => TransactionSuccessScreen(
                                        amount: widget.amount,
                                        agentName:
                                            matchedAgent?.name ?? 'Agent',
                                        agentPhone: matchedAgent?.phone ?? '',
                                        city: matchedAgent?.city ?? '',
                                        shopName:
                                            matchedAgent?.locationName ?? '',
                                        transactionId: state.transactionId,
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Agent OTP verified. Please share your OTP to agent.',
                                      ),
                                    ),
                                  );
                                }
                              }
                              return;
                            }

                            safeSetState(() {
                              inlineError = _readError(
                                body,
                                'Failed to verify OTP',
                              );
                            });
                          } catch (error) {
                            safeSetState(() {
                              inlineError = error.toString().replaceFirst(
                                'Exception: ',
                                '',
                              );
                            });
                          } finally {
                            safeSetState(() => isSubmitting = false);
                          }
                                },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xff16A34A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Verify OTP'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
          },
        );
      },
    );
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {'error': 'Invalid server response'};
    }
  }

  String _readError(Map<String, dynamic> body, String fallback) {
    final error = body['error'];
    if (error is String && error.trim().isNotEmpty) {
      return error;
    }
    if (error is Map<String, dynamic>) {
      final details = error['details'];
      if (details is List && details.isNotEmpty) {
        final first = details.first;
        if (first is Map<String, dynamic>) {
          final detailMessage = first['message'];
          if (detailMessage is String && detailMessage.trim().isNotEmpty) {
            return detailMessage;
          }
        }
      }
      final message = error['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    return fallback;
  }

  Future<void> _showSimpleDialog({
    required String title,
    required String message,
    IconData icon = Icons.info_outline,
    Color iconColor = const Color(0xff2563EB),
    Color iconBg = const Color(0xffEAF2FF),
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String primaryLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(primaryLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  Future<void> _fetchAgents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final queryParams = <String, String>{};
      if (widget.city.trim().isNotEmpty) {
        queryParams['city'] = widget.city.trim();
      }
      if (widget.latitude != null && widget.longitude != null) {
        queryParams['lat'] = widget.latitude!.toString();
        queryParams['lng'] = widget.longitude!.toString();
        queryParams['radius'] = widget.radiusKm.toString();
      }

      final uri = Uri.parse(
        '$_apiBaseUrl/agents/nearby',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Server error ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      final list = decoded is List
          ? decoded
          : (decoded['agents'] as List? ?? []);

      final agents = list
          .whereType<Map<String, dynamic>>()
          .map(_AgentSummary.fromJson)
          .where((agent) => !agent.isBanned && agent.isVerified && agent.available)
          .toList();

      final restoredRequests = await _loadRequestStateForAgents(agents);

      if (!mounted) return;
      setState(() {
        _agents = agents;
        _requestByAgentId
          ..clear()
          ..addAll(restoredRequests);
      });

      if (restoredRequests.values.any(
        (value) => value.status == 'pending' || value.status == 'approved',
      )) {
        _ensurePolling();
      } else {
        _stopPollingIfIdle();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _agents = [];
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Map<String, _RequestState>> _loadRequestStateForAgents(
    List<_AgentSummary> agents,
  ) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty || agents.isEmpty) {
      return <String, _RequestState>{};
    }

    final visibleAgentIds = agents.map((item) => item.id).toSet();

    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/transactions/requests?limit=100'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final body = _decodeBody(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <String, _RequestState>{};
      }

      final items = body['items'];
      if (items is! List) return <String, _RequestState>{};

      final restored = <String, _RequestState>{};

      for (final raw in items.whereType<Map<String, dynamic>>()) {
        final status = (raw['status'] ?? '').toString().trim().toLowerCase();
        if (status != 'pending' &&
            status != 'rejected' &&
            status != 'approved') {
          continue;
        }

        final transactionId = (raw['id'] ?? '').toString().trim();
        if (transactionId.isEmpty) continue;

        final directAgentId = (raw['agentId'] ?? '').toString().trim();
        final agent = raw['agent'] is Map<String, dynamic>
            ? raw['agent'] as Map<String, dynamic>
            : <String, dynamic>{};
        final nestedAgentId = (agent['id'] ?? '').toString().trim();
        final agentId = directAgentId.isNotEmpty
            ? directAgentId
            : nestedAgentId;
        if (agentId.isEmpty || !visibleAgentIds.contains(agentId)) continue;
        if (restored.containsKey(agentId)) continue;

        restored[agentId] = _RequestState(
          transactionId: transactionId,
          status: status,
          requestOtp: (raw['requestOtp'] ?? '').toString().trim(),
          userConfirmOtp: (raw['userConfirmOtp'] ?? '').toString().trim(),
          userConfirmedAt: DateTime.tryParse(
            (raw['userConfirmedAt'] ?? '').toString(),
          ),
          agentConfirmedAt: DateTime.tryParse(
            (raw['agentConfirmedAt'] ?? '').toString(),
          ),
          rejectionNotified: status == 'rejected',
          approvedNotified:
              status == 'approved' &&
              DateTime.tryParse((raw['approvedAt'] ?? '').toString()) != null,
        );
      }

      return restored;
    } catch (_) {
      return <String, _RequestState>{};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: const BackButton(color: Colors.black87),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available Agents',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            Text(
              '${widget.transactionType}  •  ₹${widget.amount}  •  ${widget.city}',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            tooltip: 'Refresh',
            onPressed: _fetchAgents,
          ),
          IconButton(
            icon: _isClearingAll
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.clear_all, color: Colors.black54),
            tooltip: 'Clear all requests',
            onPressed: _isClearingAll || _requestByAgentId.isEmpty
                ? null
                : _clearAllRequests,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchAgents,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_agents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 14),
              Text(
                'No agents found in ${widget.city}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Try increasing the distance range\nor check back later.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black45),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildTopInfoPart(),
        _buildListHeaderPart(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
            itemCount: _agents.length,
            itemBuilder: (_, i) => _AgentCard(
              agent: _agents[i],
              transactionType: widget.transactionType,
              amount: widget.amount,
              isRequesting: _requestingAgentId == _agents[i].id,
              requestState: _requestByAgentId[_agents[i].id],
              onRequest: () => _sendRequest(_agents[i]),
              onCancel: () => _cancelRequest(_agents[i]),
              onClear: (state) => _confirmClearRequest(_agents[i].id, state),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopInfoPart() {
    final pendingCount = _requestByAgentId.values
        .where((item) => item.status == 'pending')
        .length;
    final approvedEntry = _requestByAgentId.entries
        .where((item) => item.value.status == 'approved')
        .cast<MapEntry<String, _RequestState>?>()
        .firstWhere((entry) => entry != null, orElse: () => null);
    final approvedAgent = approvedEntry != null
        ? _agents
              .where((agent) => agent.id == approvedEntry.key)
              .cast<_AgentSummary?>()
              .firstWhere((a) => a != null, orElse: () => null)
        : null;
    final approvedState = approvedEntry?.value;
    final isOtpVerified = approvedState?.approvedAt != null;
    final firstOtp = approvedState?.requestOtp ?? '';
    final otpToShare = (approvedState?.userConfirmOtp ?? '').isNotEmpty
      ? approvedState!.userConfirmOtp
      : firstOtp;
    final bothSidesVerified = approvedState?.userConfirmedAt != null &&
      approvedState?.agentConfirmedAt != null;
    final approvedAddress = approvedAgent != null
      ? _formatAgentAddress(approvedAgent)
      : '-';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFEDE9FE),
                child: Icon(
                  Icons.location_city_outlined,
                  color: Color(0xFF5E4AE3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.city,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_agents.length} agents found • $pendingCount pending request${pendingCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (approvedEntry != null && approvedAgent != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xffE6EBF5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Agent Approved',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  _infoRow('Agent', approvedAgent.name),
                  _infoRow(
                    'Email',
                    approvedAgent.email.isNotEmpty ? approvedAgent.email : '-',
                  ),
                  _infoRow(
                    'Mobile',
                    approvedAgent.phone.isNotEmpty ? approvedAgent.phone : '-',
                  ),
                  _infoRow(
                    'Shop',
                    approvedAgent.locationName.isNotEmpty
                        ? approvedAgent.locationName
                        : '-',
                  ),
                  _infoRow(
                    'City',
                    approvedAgent.city.isNotEmpty ? approvedAgent.city : '-',
                  ),
                  _infoRow('Address', approvedAddress),
                  _infoRow('Amount', '₹${widget.amount}'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _openDirections(approvedAgent),
                      icon: const Icon(Icons.directions, size: 18),
                      label: const Text('Directions'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xff1D4ED8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xffE6EBF5)),
                  const SizedBox(height: 10),
                  const Text(
                    'Enter OTP',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xffF1F5FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        otpToShare.isEmpty ? '----' : otpToShare,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          color: Color(0xff1D4ED8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (!bothSidesVerified) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Complete OTP verification on both sides to close.',
                                  ),
                                ),
                              );
                              return;
                            }
                            _confirmClearRequest(
                              approvedEntry.key,
                              approvedEntry.value,
                            );
                          },
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Close'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xff1D4ED8)),
                            foregroundColor: const Color(0xff1D4ED8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              approvedEntry.value.userConfirmOtp.isEmpty ||
                                      approvedEntry.value.userConfirmedAt !=
                                          null
                                  ? null
                                  : () => _showConfirmAgentOtpDialog(
                                        approvedEntry.key,
                                        approvedEntry.value,
                                      ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff16A34A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Verify OTP'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAgentAddress(_AgentSummary agent) {
    final parts = <String>[];
    if (agent.address.isNotEmpty) parts.add(agent.address);
    if (agent.locationName.isNotEmpty) parts.add(agent.locationName);
    if (agent.city.isNotEmpty) parts.add(agent.city);
    if (parts.isEmpty) return '-';
    return parts.join(', ');
  }

  Widget _buildListHeaderPart() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        'Available agents in ${widget.city}',
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
