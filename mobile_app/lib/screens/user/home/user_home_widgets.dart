part of 'user_home_screen.dart';

extension _UserHomeWidgets on _UserHomeScreenState {
  // -------------------------------------------------------
  // Header
  Widget _buildHeader(BuildContext context) {
    return Row(
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
            radius: 24,
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
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 3),
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
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Color(0xff9CA3AF),
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
              icon: const Icon(Icons.notifications_outlined, size: 28),
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
                    return Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
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
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------
  // Hero card
  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF0FF), Color(0xFFF6FAFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFDEE8FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.place_outlined, size: 18, color: Color(0xFF2962FF)),
              ),
              const SizedBox(width: 10),
              const Text(
                'Current Area',
                style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _cityLabel,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          const Text('Tap header area to switch or update location', style: TextStyle(color: Colors.black54)),
        ],
      ),
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
    return Column(
      children: [
        _infoCard('Verified Agents'),
        const SizedBox(height: 10),
        _infoCard('Secure OTP Exchange'),
        const SizedBox(height: 10),
        _infoCard('Instant Transactions'),
      ],
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              sectionTitle,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              sectionCity,
              style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w600),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Nearby Banks & ATMs',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xffDDE7FF)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.map_outlined, color: Color(0xff2563EB), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Open Map',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ],
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
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 150,
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
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: ElevatedButton(
                    onPressed: _openFullMap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2962FF),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'View All →',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
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
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
          Text(
            'Emergency / SOS',
            style: TextStyle(fontWeight: FontWeight.bold),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6ECFF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: Color(0xFF2962FF), size: 20),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6ECFF)),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agent.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
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
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
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
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 32,
                child: _buildAgentRequestButton(status),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(distanceLabel, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w500)),
              const SizedBox(width: 10),
              if (agent.locationName.isNotEmpty)
                Expanded(
                  child: Text(
                    agent.locationName,
                    style: const TextStyle(color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                Expanded(
                  child: Text(
                    agent.city,
                    style: const TextStyle(color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                  ),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
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
