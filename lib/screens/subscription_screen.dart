import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../services/subscription_service.dart';
import 'backup_restore_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final PageController _pageController = PageController(viewportFraction: 0.85);
  late ConfettiController _confettiController;

  String _currentPlan = 'free';
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 4),
    );
    // Confetti plays immediately when the user enters the subscription page!
    _confettiController.play();
    _loadCurrentPlan();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentPlan() async {
    String plan = await _subscriptionService.getCurrentPlan();
    if (!mounted) return;
    setState(() {
      _currentPlan = plan;
      if (plan == 'premium') _currentPage = 1;
      if (plan == 'family') _currentPage = 2;
    });
  }

  // Show Payment Method Bottom Sheet when user taps upgrade
  void _showPaymentMethodDialog(String planName, double price) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Payment Method for $planName',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Amount to pay: Rs. ${price.toStringAsFixed(0)}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 20),

              // 1. JazzCash Option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.red,
                  ),
                ),
                title: const Text(
                  'JazzCash Mobile Account',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Simulated Instant Payment'),
                onTap: () {
                  Navigator.pop(context);
                  _processUpgrade(planName, price, 'JazzCash');
                },
              ),
              const Divider(),

              // 2. EasyPaisa Option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.phone_android, color: Colors.green),
                ),
                title: const Text(
                  'EasyPaisa Wallet',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Simulated Instant Payment'),
                onTap: () {
                  Navigator.pop(context);
                  _processUpgrade(planName, price, 'EasyPaisa');
                },
              ),
              const Divider(),

              // 3. Sandbox Fast Test Option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bolt, color: Colors.purple),
                ),
                title: const Text(
                  'Sandbox Fast Test',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Bypass for Evaluators / FYP Panel'),
                onTap: () {
                  Navigator.pop(context);
                  _processUpgrade(planName, price, 'Sandbox Test');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Process Upgrade & Save Payment Details + Timestamp
  Future<void> _processUpgrade(
    String planName,
    double price,
    String paymentMethod,
  ) async {
    try {
      // 1️⃣ Save details to Firestore via subscription service
      await _subscriptionService.updateSubscriptionWithMethod(
        planName.toLowerCase(),
        price,
        paymentMethod,
      );

      if (!mounted) return;

      setState(() => _currentPlan = planName.toLowerCase());

      // Play confetti again on successful purchase for extra celebration!
      _confettiController.play();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🎉 Upgraded to $planName via $paymentMethod Successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // 2️⃣ 🚀 Only redirect user to the Backup & Restore screen if they bought the Family plan!
      if (planName.toLowerCase() == 'family') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const BackupRestoreScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to complete upgrade: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Subscription Plans',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple.shade700,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.purple.shade700, Colors.purple.shade900],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Fancy Multi-Colored Gradient Header Text
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Colors.yellowAccent,
                        Colors.pinkAccent,
                        Colors.cyanAccent,
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      'Choose Your Protection Plan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'Select a tier that matches your security needs and unlock advanced safety features.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Horizontal Swipeable Cards Carousel (PageView)
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      children: [
                        // Tier 1: Free
                        _buildTierCard(
                          name: 'Free',
                          price: 'Rs. 0',
                          subtitle: 'Basic Security',
                          features: [
                            'GPS Tracking',
                            'Intruder Capture',
                            'View Dashboard',
                          ],
                          isCurrent: _currentPlan == 'free',
                          buttonText: 'Current Plan',
                          onTap: null,
                        ),

                        // Tier 2: Premium
                        _buildTierCard(
                          name: 'Premium',
                          price: 'Rs. 99 / month',
                          subtitle: 'Advanced Control',
                          features: [
                            'All Free Features',
                            'Remote Commands (Lock / Ring / Enable Theft Mode)',
                          ],
                          isCurrent: _currentPlan == 'premium',
                          buttonText: 'Upgrade to Premium',
                          onTap: () =>
                              _showPaymentMethodDialog('Premium', 99.0),
                        ),

                        // Tier 3: Family / Pro
                        _buildTierCard(
                          name: 'Family',
                          price: 'Rs. 199 / month',
                          subtitle: 'Ultimate Protection',
                          features: [
                            'All Premium Features',
                            'Backup & Restore',
                          ],
                          isCurrent: _currentPlan == 'family',
                          buttonText: 'Upgrade to Family',
                          onTap: () =>
                              _showPaymentMethodDialog('Family', 199.0),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Page Indicator Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? Colors.white
                              : Colors.white38,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Confetti Animation Falling
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 1.57,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.2,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.yellow,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard({
    required String name,
    required String price,
    required String subtitle,
    required List<String> features,
    required bool isCurrent,
    required String buttonText,
    required VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Text(
              price,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade700,
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: ListView(
                children: features.map((feature) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            feature,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            if (onTap != null && !isCurrent)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isCurrent ? 'Current Active Plan' : buttonText,
                    style: TextStyle(
                      color: isCurrent ? Colors.green : Colors.grey,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
