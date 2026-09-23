import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:country_code_picker/country_code_picker.dart';
import '../models/purchase_cart_item.dart';
import '../services/subscription_service.dart';
import '../services/app_config.dart';
import '../services/sandbox_sms_service.dart';
import '../services/notification_service.dart';
import 'card_checkout_screen.dart';
import 'invoices/jazzcash_invoice_screen.dart';
import 'invoices/easypaisa_invoice_screen.dart';
import 'invoices/card_invoice_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  late final PageController _pageController;
  late final ConfettiController _confettiController;

  String _currentPlan = 'free';
  int _currentPage = 0;

  // Toggle this to true for live production mode, or false for Sandbox/Viva testing
  final bool _isLiveProductionMode = false;

  // Sandbox pre-authorized test numbers for offline/viva testing
  final List<String> _allowedTestNumbers = [
    '+923005171794',
    '+923144964339',
    '+923241923864',
    '+923128719043',
    '+923157633912',
    '03005171794',
    '03144964339',
    '03241923864',
    '03128719043',
    '03157633912',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _loadCurrentPlan();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiController.play();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentPlan() async {
    String plan = await _subscriptionService.getCurrentPlan();
    if (!mounted) return;

    int targetPage = 0;
    if (plan.toLowerCase() == 'premium') targetPage = 1;
    if (plan.toLowerCase() == 'family') targetPage = 2;

    setState(() {
      _currentPlan = plan.toLowerCase();
      _currentPage = targetPage;
    });

    if (_pageController.hasClients) {
      _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showPaymentMethodDialog(PurchaseCartItem cartItem) {
    if (_currentPlan != 'free' && _currentPlan != 'none') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You already have an active subscription plan. Complete or manage your current subscription first.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
                'Select Payment Method for ${cartItem.title}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Amount to pay: Rs. ${cartItem.price.toStringAsFixed(0)} ${_isLiveProductionMode ? "(Live Mode)" : "(Sandbox Mode)"}',
                style: TextStyle(
                  color: _isLiveProductionMode
                      ? Colors.green.shade700
                      : Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
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
                subtitle: Text(
                  _isLiveProductionMode
                      ? 'Real Live Merchant Gateway Request'
                      : 'Secure Wallet OTP Checkout',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showSecureCheckoutDialog(cartItem, 'JazzCash');
                },
              ),
              const Divider(),
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
                subtitle: Text(
                  _isLiveProductionMode
                      ? 'Real Live Merchant Gateway Request'
                      : 'Secure Wallet OTP Checkout',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showSecureCheckoutDialog(cartItem, 'EasyPaisa');
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.credit_card, color: Colors.blue),
                ),
                title: const Text(
                  'Credit / Debit Card',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('PayFast / Visa / Mastercard / Stripe'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CardCheckoutScreen(cartItem: cartItem),
                    ),
                  );

                  if (!mounted) return;

                  if (result != null && result['success'] == true) {
                    _processCardUpgrade(
                      cartItem,
                      result['method'] ?? 'Stripe Global',
                      result['txnId'],
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSecureCheckoutDialog(
    PurchaseCartItem cartItem,
    String paymentMethod,
  ) {
    String selectedCountryCode = '+92';
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController mpinController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                _isLiveProductionMode
                    ? '$paymentMethod Live Checkout'
                    : '$paymentMethod Sandbox Checkout',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paying PKR ${cartItem.price.toStringAsFixed(0)} for ${cartItem.title}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CountryCodePicker(
                            onChanged: (country) {
                              selectedCountryCode = country.dialCode ?? '+92';
                            },
                            initialSelection: 'PK',
                            favorite: const ['+92', 'PK'],
                            showCountryOnly: false,
                            showOnlyCountryWhenClosed: false,
                            alignLeft: false,
                          ),
                          Container(
                            height: 30,
                            width: 1,
                            color: Colors.grey.shade300,
                          ),
                          Expanded(
                            child: TextField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                hintText: '3001234567',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: mpinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      decoration: InputDecoration(
                        labelText: _isLiveProductionMode
                            ? 'Real Gateway PIN / OTP'
                            : '4-Digit MPIN / Mock OTP',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.lock),
                        counterText: '',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          String localNumber = phoneController.text.trim();

                          if (localNumber.startsWith('0')) {
                            localNumber = localNumber.substring(1);
                          }

                          String cleanNumber =
                              '$selectedCountryCode$localNumber'.replaceAll(
                                RegExp(r'\s+'),
                                '',
                              );
                          String enteredMpin = mpinController.text.trim();

                          final RegExp phoneRegex = RegExp(
                            r'^\+[1-9]\d{7,14}$',
                          );

                          if (!phoneRegex.hasMatch(cleanNumber)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter a valid phone number format with country code.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (!_isLiveProductionMode) {
                            bool isAuthorized =
                                _allowedTestNumbers.contains(cleanNumber) ||
                                _allowedTestNumbers.contains(
                                  phoneController.text.trim(),
                                );
                            if (!isAuthorized) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Invalid sandbox number! Use one of the authorized test numbers.',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                          }

                          if (enteredMpin.length != 4) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter a valid 4-digit PIN/OTP.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isLoading = true);

                          if (!_isLiveProductionMode) {
                            await Future.delayed(const Duration(seconds: 2));
                            await SandboxSmsService().sendMockOtp(cleanNumber);
                          } else {
                            await Future.delayed(const Duration(seconds: 3));
                          }

                          if (!mounted) return;
                          Navigator.pop(dialogContext);
                          _processUpgrade(cartItem, paymentMethod, cleanNumber);
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Authorize & Pay',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _processCardUpgrade(
    PurchaseCartItem cartItem,
    String paymentMethod,
    String txnId,
  ) async {
    try {
      await _subscriptionService.updateSubscriptionWithMethod(
        cartItem.featureId.replaceAll('tier_', ''),
        cartItem.price.toStringAsFixed(0),
        paymentMethod,
        txnId,
      );

      // Added notification call here
      await NotificationService().showNotification(
        title: 'Payment Successful',
        body: 'Upgraded to ${cartItem.title} via $paymentMethod. Ref: $txnId',
      );

      if (!mounted) return;

      setState(() => _currentPlan = cartItem.featureId.replaceAll('tier_', ''));
      _confettiController.play();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CardInvoiceScreen(
            authCode: txnId,
            totalAmount: cartItem.price,
            cartItemOrItems: cartItem,
          ),
        ),
      );
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

  Future<void> _processUpgrade(
    PurchaseCartItem cartItem,
    String paymentMethod,
    String mobileNo,
  ) async {
    try {
      String txnId = _isLiveProductionMode
          ? 'LIVE-TXN-${DateTime.now().millisecondsSinceEpoch}'
          : 'TXN${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      await _subscriptionService.updateSubscriptionWithMethod(
        cartItem.featureId.replaceAll('tier_', ''),
        cartItem.price.toStringAsFixed(0),
        paymentMethod,
        txnId,
      );

      // Added notification call here
      await NotificationService().showNotification(
        title: 'Payment Successful',
        body: 'Upgraded to ${cartItem.title} via $paymentMethod. Ref: $txnId',
      );

      if (!mounted) return;

      setState(() => _currentPlan = cartItem.featureId.replaceAll('tier_', ''));
      _confettiController.play();

      if (paymentMethod.toLowerCase().contains('jazzcash')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JazzCashInvoiceScreen(
              items: [cartItem],
              txnId: txnId,
              totalAmount: cartItem.price,
            ),
          ),
        );
      } else if (paymentMethod.toLowerCase().contains('easypaisa')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EasypaisaInvoiceScreen(
              items: [cartItem],
              token: txnId,
              totalAmount: cartItem.price,
            ),
          ),
        );
      } else {
        _showSuccessDialog(cartItem, paymentMethod, txnId);
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

  void _showSuccessDialog(
    PurchaseCartItem cartItem,
    String paymentMethod,
    String txnId,
  ) {
    _confettiController.play();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('Payment Successful!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are now subscribed to the ${cartItem.title}.'),
            const SizedBox(height: 8),
            Text('Amount Paid: Rs. ${cartItem.price.toStringAsFixed(0)}'),
            Text('Method: $paymentMethod'),
            Text('Transaction ID: $txnId'),
            Text(
              'Mode: ${_isLiveProductionMode ? "Live Production" : "Sandbox"}',
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade700,
            ),
            onPressed: () {
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasActivePlan = _currentPlan != 'free' && _currentPlan != 'none';

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(
              _isLiveProductionMode
                  ? 'Subscription Plans (Live)'
                  : 'Subscription Plans (Sandbox)',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.purple.shade700,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Container(
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
                      'Select a tier that matches your security needs. Only one active plan can be held at a time.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
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
                          hasActiveConflict: hasActivePlan,
                        ),
                        _buildTierCard(
                          name: 'Premium',
                          price: 'Rs. 50 / month',
                          subtitle: 'Advanced Control',
                          features: [
                            'All Free Features',
                            'Remote Commands (Lock / Ring / Enable Theft Mode)',
                          ],
                          isCurrent: _currentPlan == 'premium',
                          buttonText: 'Upgrade to Premium',
                          onTap: () {
                            final cartItem = PurchaseCartItem(
                              featureId: 'tier_premium',
                              title: 'Premium Plan',
                              price: 50.0,
                            );
                            _showPaymentMethodDialog(cartItem);
                          },
                          hasActiveConflict:
                              hasActivePlan && _currentPlan != 'premium',
                        ),
                        _buildTierCard(
                          name: 'Family',
                          price: 'Rs. 100 / month',
                          subtitle: 'Ultimate Protection',
                          features: [
                            'All Premium Features',
                            'Backup & Restore',
                          ],
                          isCurrent: _currentPlan == 'family',
                          buttonText: 'Upgrade to Family',
                          onTap: () {
                            final cartItem = PurchaseCartItem(
                              featureId: 'tier_family',
                              title: 'Family Plan',
                              price: 100.0,
                            );
                            _showPaymentMethodDialog(cartItem);
                          },
                          hasActiveConflict:
                              hasActivePlan && _currentPlan != 'family',
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
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 30,
            gravity: 0.2,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple,
              Colors.yellowAccent,
              Colors.cyanAccent,
            ],
          ),
        ),
      ],
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
    required bool hasActiveConflict,
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
            const SizedBox(height: 12),
            if (onTap != null && !isCurrent && !hasActiveConflict)
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
                    isCurrent
                        ? 'Current Active Plan'
                        : hasActiveConflict
                        ? 'Plan Locked (Active Plan Exists)'
                        : buttonText,
                    style: TextStyle(
                      color: isCurrent ? Colors.green : Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
