part of 'user_home_screen.dart';

extension _UserHomeWidgets on _UserHomeScreenState {
  // -------------------------------------------------------
  // Header
  Widget _buildHeader(BuildContext context) {
    final scaleFactor = Responsive.scaleFactor(context);
    final avatarDiameter = (44 * scaleFactor).clamp(40.0, 48.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
      child: Row(
        children: [
        GestureDetector(
          onTap: () {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                )
                .then((_) {
              _loadPhoto();
              _loadProfileName();
            });
          },
          child: CircleAvatar(
            radius: avatarDiameter / 2,
            backgroundColor: const Color(0xFF2962FF),
            backgroundImage: _profilePhotoBytes != null
                ? MemoryImage(_profilePhotoBytes!)
                : (_photoFile != null ? FileImage(_photoFile!) : null),
            child: _profilePhotoBytes == null && _photoFile == null
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: _showLocationSheet,
            borderRadius: BorderRadius.circular(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi $_profileFirstName',
                  style: TextStyle(
                    fontSize: 20 * scaleFactor,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Color(0xff2563EB),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _cityLabel.trim().isEmpty ? 'Set your location' : _cityLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                          fontSize: 14 * scaleFactor,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Stack(
          children: [
            IconButton(
              onPressed: _openNotificationCenter,
              icon: const Icon(Icons.notifications_outlined, size: 24),
            ),
            StreamBuilder<int>(
              stream: LocalNotificationService.instance.onBadgeCount,
              initialData: LocalNotificationService.instance.badgeCount,
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                if (count <= 0) return const SizedBox.shrink();
                return Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        ],
      ),
    );
  }

  void _openNotificationCenter() {
    LocalNotificationService.instance.markAllSeen();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xffEAF0FF), Color(0xffF6FAFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xffE6EBF5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_outlined, color: Color(0xff2563EB)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Notifications',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              LocalNotificationService.instance.clearAllNotifications(),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xff2563EB),
                          ),
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<LocalNotificationItem>>(
                    stream: LocalNotificationService.instance.onNotificationList,
                    initialData: LocalNotificationService.instance.activeNotifications,
                    builder: (context, snapshot) {
                      final items = snapshot.data ?? [];
                      if (items.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: Text('No notifications yet')),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (context, index) => const Divider(height: 18),
                        itemBuilder: (itemContext, index) {
                          final item = items[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(item.message),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              Navigator.of(sheetContext).pop();
                              if (item.payload.startsWith('user_request:')) {
                                final requestId = item.payload.replaceFirst('user_request:', '').trim();
                                if (requestId.isNotEmpty) {
                                  Navigator.of(this.context).push(
                                    MaterialPageRoute(
                                      builder: (_) => MyRequestsScreen(initialRequestId: requestId),
                                    ),
                                  );
                                }
                              } else if (item.payload.startsWith('user_approved:')) {
                                final contextArgs = await AvailableAgentsContextStore.load();
                                if (!mounted) return;
                                Navigator.of(this.context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AvailableAgentsScreen(
                                      city: contextArgs?.city.isNotEmpty == true
                                          ? contextArgs!.city
                                          : 'your area',
                                      latitude: contextArgs?.latitude,
                                      longitude: contextArgs?.longitude,
                                      radiusKm: contextArgs?.radiusKm ?? 5.0,
                                      transactionType: contextArgs?.transactionType ?? 'UPI → Cash',
                                      amount: contextArgs?.amount ?? '1000',
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------
  // Cash actions
  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            title: 'Cash Out',
            subtitle: 'UPI to Cash',
            icon: Icons.south_west_rounded,
            gradient: const LinearGradient(
              colors: [Color(0xFF1FAE63), Color(0xFF45C97A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const UpiToCashScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionButton(
            title: 'Cash In',
            subtitle: 'Cash to UPI',
            icon: Icons.north_east_rounded,
            gradient: const LinearGradient(
              colors: [Color(0xFF2D7CFF), Color(0xFF49A5FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CashToUpiScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------
  // Trust indicators
  Widget _buildTrustRow(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F0FF), Color(0xFFF0EEFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Convert Digital Money to Cash',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Nearby & Secure',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(
                child: _TrustChip(icon: Icons.verified_rounded, label: 'Verified Agents'),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _TrustChip(icon: Icons.lock_outline_rounded, label: 'Secure OTP'),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _TrustChip(icon: Icons.flash_on_rounded, label: 'Instant Transactions'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F2937),
      ),
    );
  }

  // -------------------------------------------------------
  // Agents
  Widget _buildAgents(BuildContext context) {
    if (_isLoadingAgents) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE6ECFF)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Loading nearby agents...'),
          ],
        ),
      );
    }

    if (_agentsError != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE6ECFF)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.black45),
            const SizedBox(width: 10),
            Expanded(child: Text(_agentsError!, style: const TextStyle(color: Colors.black54))),
            TextButton(
              onPressed: _fetchNearbyAgents,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_nearbyAgents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE6ECFF)),
        ),
        child: const Text(
          'No agents found within 10 km.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    const sectionTitle = 'Nearby Trusted Agents';
    final sectionCity = (_agentsSectionCityLabel ?? _cityLabel).trim();
    final visibleAgents = _nearbyAgents.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildSectionTitle(sectionTitle),
            Text(
              sectionCity,
              style: const TextStyle(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...visibleAgents.map(
          (agent) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _agentCard(agent: agent),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------
  // Map preview
  Widget _buildMapPreview() {
    final mapHeight = (MediaQuery.sizeOf(context).width * 0.34).clamp(120.0, 170.0);
    final places = [
      {'name': 'State Bank of India', 'type': 'Bank', 'distance': '0.8 km'},
      {'name': 'HDFC ATM', 'type': 'ATM', 'distance': '1.2 km'},
      {'name': 'ICICI Branch', 'type': 'Bank', 'distance': '2.1 km'},
    ];
    return InkWell(
      onTap: _openFullMap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xffEAF0FF), Color(0xffF7FBFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xffE6EBF5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildSectionTitle('Nearby Banks & ATMs'),
                OutlinedButton.icon(
                  onPressed: _openFullMap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xff2563EB),
                    side: const BorderSide(color: Color(0xffDDE7FF)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text(
                    'Open Map',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _MapFilterChip(label: 'All', selected: true),
                _MapFilterChip(label: 'Banks'),
                _MapFilterChip(label: 'ATMs'),
                _MapFilterChip(label: 'Open now'),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: mapHeight,
                child: IgnorePointer(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _mapCenter,
                      zoom: 13,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    markers: _mapMarkers,
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Column(
              children: places
                  .map(
                    (place) => _nearbyPlaceRow(
                      name: place['name']!,
                      type: place['type']!,
                      distance: place['distance']!,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap any place or open map for directions.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nearbyPlaceRow({
    required String name,
    required String type,
    required String distance,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE6EBF5)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xffEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              type == 'ATM' ? Icons.account_balance_wallet : Icons.account_balance,
              color: const Color(0xff2563EB),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  type,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            distance,
            style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xff2563EB)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // SOS
  Widget _buildSos() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xffFFF3E0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning, color: Colors.orange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Emergency / SOS',
              style: TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // Reusable widgets
  Widget _actionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed ?? () {},
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w400),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _agentCard({
    required _HomeAgentSummary agent,
  }) {
    final status = _requestStatusByAgentId[agent.id];
    final distanceKm = _distanceKmTo(agent);
    final distanceLabel = distanceKm > 0 ? '${distanceKm.toStringAsFixed(1)} km' : 'Nearby';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6ECFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFEAF0FF),
                backgroundImage: agent.profilePhotoBytes != null
                    ? MemoryImage(agent.profilePhotoBytes!)
                    : null,
                child: agent.profilePhotoBytes == null
                    ? const Icon(Icons.person, size: 18, color: Color(0xFF2962FF))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agent.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      agent.locationName.isNotEmpty ? agent.locationName : agent.city,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xffECFDF3),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xffA7F3D0)),
                          ),
                          child: const Text(
                            'Verified',
                            style: TextStyle(
                              color: Color(0xff059669),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xffEAF0FF),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xffC7D9FF)),
                          ),
                          child: const Text(
                            'Available now',
                            style: TextStyle(
                              color: Color(0xff2563EB),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xffFFF7E6),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xffFDE68A)),
                          ),
                          child: Text(
                            agent.averageRating == null
                                ? 'New'
                                : '${agent.averageRating!.toStringAsFixed(1)} (${agent.ratingCount})',
                            style: const TextStyle(
                              color: Color(0xffB45309),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: _buildAgentRequestButton(status),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 14, color: Color(0xFF6B7280)),
              const SizedBox(width: 4),
              Text(
                distanceLabel,
                style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w500, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgentRequestButton(String? status) {
    if (status == 'approved') {
      return ElevatedButton(
        onPressed: _openAvailableAgentsFromHome,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1D4ED8),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          elevation: 0,
        ),
        child: const Text('Request Again', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      );
    }

    if (status == 'pending') {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xffEEF2FF),
          foregroundColor: const Color(0xff4338CA),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          elevation: 0,
        ),
        child: const Text('Requested', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      );
    }

    return ElevatedButton(
      onPressed: _openAvailableAgentsFromHome,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2962FF),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        elevation: 0,
      ),
      child: const Text('Request', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  void _showLocationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Location Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xffF8FAFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xffE6EBF5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xffE0ECFF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.my_location,
                          color: Color(0xff2563EB),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Use Current Location',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Switch.adaptive(
                        value: _useCurrentLocation,
                        activeColor: const Color(0xff2563EB),
                        onChanged: (val) async {
                          if (val) {
                            await _applyCurrentLocation();
                            return;
                          }
                          _setCurrentLocationEnabled(false);
                        },
                      ),
                    ],
                  ),
                ),
                if (_isFetchingLocation) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MapFilterChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _MapFilterChip({
    required this.label,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? const Color(0xff2563EB) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? const Color(0xff2563EB) : const Color(0xffE6EBF5),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : const Color(0xff1F2937),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TrustChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TrustChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE6FF)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF2563EB)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              softWrap: true,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F2937),
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
