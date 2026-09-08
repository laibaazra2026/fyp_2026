import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../services/subscription_service.dart';
import 'backup_restore_screen.dart';
import 'gateway_success_screen.dart';

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
      _currentPlan = plan.toLowerCase();
      if (_currentPlan == 'premium') _currentPage = 1;
      if (_currentPlan == 'family') _currentPage = 2;
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
                  _showGatewayCheckoutDialog(planName, price, 'JazzCash');
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
                  _showGatewayCheckoutDialog(planName, price, 'EasyPaisa');
                },
              ),
              const Divider(),

              // 3. Sandbox
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
                  _showGatewayCheckoutDialog(planName, price, 'Sandbox Test');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Secure Gateway & SMS Test Whitelist Checkout Dialog
  void _showGatewayCheckoutDialog(
    String planName,
    double price,
    String gatewayName,
  ) {
    final phoneController = TextEditingController();
    final pinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$gatewayName Secure Checkout'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Paying PKR ${price.toStringAsFixed(0)} for $planName Tier'),
              const SizedBox(height: 12),

              // Phone Number Field with Whitelist Validation
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 13,
                decoration: const InputDecoration(
                  labelText: 'Test Mobile Wallet No',
                  hintText: '+923XXXXXXXXX or 03XXXXXXXXX',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                validator: _subscriptionService.validateAndNormalizeNumber,
              ),
              const SizedBox(height: 12),

              // Mock MPIN / OTP Field
              TextFormField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: '4-Digit MPIN / Mock OTP',
                  hintText: '1234',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                validator: (val) => (val == null || val.length != 4)
                    ? 'Enter 4-digit mock MPIN'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade700,
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                String inputPhone = phoneController.text.trim();
                Navigator.pop(dialogContext); // Close checkout dialog safely

                // Show loading progress
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (loadingContext) =>
                      const Center(child: CircularProgressIndicator()),
                );

                try {
                  // 1. Trigger Sandbox SMS to the test number and log to Firestore
                  await _subscriptionService.sendSandboxSms(
                    recipientNumber: inputPhone,
                    planName: planName,
                    price: price,
                    gateway: gatewayName,
                  );

                  String txnId = 'SBX-${DateTime.now().millisecondsSinceEpoch}';

                  // 2. Update user subscription state in Firestore
                  await _subscriptionService.updateSubscriptionWithMethod(
                    planName,
                    price,
                    gatewayName,
                    verifiedPhoneNumber: inputPhone,
                    transactionId: txnId,
                  );

                  if (!mounted) return;
                  Navigator.pop(context); // Dismiss loading progress dialog

                  setState(() => _currentPlan = planName.toLowerCase());
                  _confettiController.play();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '🎉 Upgraded to $planName via $gatewayName Successfully! SMS Dispatched.',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );

                  if (planName.toLowerCase() == 'family') {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GatewaySuccessScreen(
                          planName: planName,
                          price: price,
                          gatewayName: gatewayName,
                          transactionId: txnId,
                        ),
                      ),
                    );
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GatewaySuccessScreen(
                          planName: planName,
                          price: price,
                          gatewayName: gatewayName,
                          transactionId: txnId,
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (!mounted) return;
                  Navigator.pop(context); // Dismiss loading progress dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Authorize & Pay',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
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
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      children: [
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
                physics: const BouncingScrollPhysics(),
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
