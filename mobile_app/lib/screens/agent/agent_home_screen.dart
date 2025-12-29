import 'package:flutter/material.dart';

import 'agent_registration_screen.dart';

class AgentHomeScreen extends StatefulWidget {
  const AgentHomeScreen({super.key});

  @override
  State<AgentHomeScreen> createState() => _AgentHomeScreenState();
}

class _AgentHomeScreenState extends State<AgentHomeScreen> {
  bool _isOnline = true;
  int _currentIndex = 0;
  bool _pulseUp = true;

  final String _shopName = 'Green Mart Kiosk';
  final String _agentName = 'Rahul Patil';
  final String _cityName = 'Pune, Maharashtra';
  final double _rating = 4.6; // TODO: Backend will calculate agent rating from user feedback

  final List<Map<String, String>> _liveRequests = [
    {
      'name': 'Ananya K.',
      'amount': '₹1,200',
      'location': 'Viman Nagar',
      'type': 'UPI → Cash',
    },
    {
      'name': 'Rohit S.',
      'amount': '₹2,500',
      'location': 'Kharadi',
      'type': 'Cash → UPI',
    },
    {
      'name': 'Meera T.',
      'amount': '₹900',
      'location': 'Wagholi',
      'type': 'UPI → Cash',
    },
    {
      'name': 'Sana P.',
      'amount': '₹1,700',
      'location': 'Kalyani Nagar',
      'type': 'Cash → UPI',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.4,
        leadingWidth: 170,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AgentRegistrationScreen()),
              );
            },
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _agentName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          Row(
            children: [
              Text(
                _isOnline ? 'Online' : 'Offline',
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
              ),
              Switch(
                value: _isOnline,
                onChanged: (value) {
                  setState(() => _isOnline = value);
                  // TODO: Backend will update agent availability status
                },
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroCard(),
              const SizedBox(height: 16),
              _buildTransactionSummary(),
              const SizedBox(height: 18),
              _buildLiveRequestsSection(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        onTap: (index) {
          setState(() => _currentIndex = index);

          if (index == 1) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Map (demo placeholder)')),
            );
          } else if (index == 2) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Transactions (demo placeholder)')),
            );
          } else if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AgentRegistrationScreen()),
            );
          } else if (index == 4) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Agent tab (you are here)')),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Transactions'),
          BottomNavigationBarItem(icon: Icon(Icons.verified_user), label: 'Agent'),
          //BottomNavigationBarItem(icon: Icon(Icons.verified_user), label: 'Agent'),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    final displayShop = _shopName.isNotEmpty ? _shopName : 'Independent Agent';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color.fromARGB(255, 186, 212, 250), Color.fromARGB(255, 238, 177, 140)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayShop,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            _agentName,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.blue, size: 18),
              const SizedBox(width: 4),
              Text(_cityName, style: const TextStyle(color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.star, color: Colors.orange, size: 18),
              const SizedBox(width: 4),
              Text('$_rating • Demo rating'),
            ],
          ),
          // TODO: Backend will calculate agent rating from user feedback
        ],
      ),
    );
  }

  Widget _buildTransactionSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transaction Summary',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _summaryCard('Today\'s Requests', '3')),
            const SizedBox(width: 10),
            Expanded(child: _summaryCard('Total Transactions', '48')),
            const SizedBox(width: 10),
            Expanded(child: _summaryCard('Earnings', '₹2,350')),
          ],
        ),
        // TODO: Backend will fetch transaction summary and live requests
      ],
    );
  }

  Widget _summaryCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLiveRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Text(
              'Live Transaction Requests',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 10),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: _pulseUp ? 0.7 : 1.0, end: _pulseUp ? 1.0 : 0.7),
              duration: const Duration(milliseconds: 800),
              onEnd: () => setState(() => _pulseUp = !_pulseUp),
              builder: (context, value, child) {
                return Container(
                  width: 16 * value,
                  height: 16 * value,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 6 * value,
                        spreadRadius: 1.5,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._liveRequests.map(_requestCard).toList(),
        // TODO: Backend will handle approve/reject request actions
      ],
    );
  }

  Widget _requestCard(Map<String, String> request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(request['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(request['amount'] ?? '', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      request['type'] ?? 'UPI → Cash',
                      style: const TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.blueGrey),
              const SizedBox(width: 4),
              Text(request['location'] ?? '', style: const TextStyle(color: Colors.black54)),
            ],
          ),
          // TODO: Backend will provide request type from API
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Approved (demo action)')),
                    );
                    debugPrint('Approve clicked for ${request['name']}');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: const Text('Approve'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rejected (demo action)')),
                    );
                    debugPrint('Reject clicked for ${request['name']}');
                  },
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
                  child: const Text('Reject'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
