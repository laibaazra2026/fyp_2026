import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/purchase_cart_item.dart';
import '../services/notification_service.dart';
import '../services/app_config.dart'; // Import config for live vs sandbox mode

enum PaymentGatewayType { payfast, jazzCashCard, stripe }

class CardCheckoutScreen extends StatefulWidget {
  final PurchaseCartItem cartItem;

  const CardCheckoutScreen({super.key, required this.cartItem});

  @override
  State<CardCheckoutScreen> createState() => _CardCheckoutScreenState();
}

class _CardCheckoutScreenState extends State<CardCheckoutScreen> {
  PaymentGatewayType _selectedGateway = PaymentGatewayType.payfast;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();

  bool _isLoading = false;

  // Pre-authorized test cards for sandbox/viva testing mode
  final List<String> _allowedTestCards = [
    '4111 2222 3333 4444',
    '5555 4444 3333 2222',
    '4000 1234 5678 9010',
  ];

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardHolderController.dispose();
    super.dispose();
  }

  void _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    // Sandbox card validation check
    String enteredCard = _cardNumberController.text.trim();
    if (!AppConfig.isLiveProductionMode) {
      if (!_allowedTestCards.contains(enteredCard)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sandbox Mode: Please use a valid pre-authorized test card number.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    // Simulate secure gateway processing delay
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() => _isLoading = false);

    String txnId = AppConfig.isLiveProductionMode
        ? 'CC-LIVE-TXN-${DateTime.now().millisecondsSinceEpoch}'
        : 'CC-TXN${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    String gatewayName = _getGatewayName(_selectedGateway);
    String amountStr = widget.cartItem.price.toStringAsFixed(0);

    // Call the centralized handler to update Firestore, logs, and notifications
    await handleSuccessfulPayment(
      gateway: gatewayName,
      planName: widget.cartItem.title,
      transactionId: txnId,
      mobileNo: 'N/A', // Cards don't require mobile numbers
      amount: amountStr,
    );

    // Return result back to subscription screen
    Navigator.pop(context, {
      'success': true,
      'method': gatewayName,
      'txnId': txnId,
    });
  }

  String _getGatewayName(PaymentGatewayType type) {
    switch (type) {
      case PaymentGatewayType.payfast:
        return 'PayFast Card Gateway';
      case PaymentGatewayType.jazzCashCard:
        return 'JazzCash Mastercard/Visa';
      case PaymentGatewayType.stripe:
        return 'Stripe Global';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppConfig.isLiveProductionMode
              ? 'Secure Card Checkout (Live)'
              : 'Secure Card Checkout (Sandbox)',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.purple.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paying PKR ${widget.cartItem.price.toStringAsFixed(0)} for ${widget.cartItem.title}',
                style: TextStyle(
                  color: AppConfig.isLiveProductionMode
                      ? Colors.green.shade700
                      : Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Card Gateway',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<PaymentGatewayType>(
                value: _selectedGateway,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                items: PaymentGatewayType.values.map((gateway) {
                  return DropdownMenuItem(
                    value: gateway,
                    child: Text(_getGatewayName(gateway)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedGateway = val);
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Card Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cardHolderController,
                decoration: const InputDecoration(
                  labelText: 'Cardholder Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Please enter cardholder name'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                  CardNumberFormatter(),
                ],
                decoration: InputDecoration(
                  labelText: 'Card Number',
                  hintText: AppConfig.isLiveProductionMode
                      ? 'XXXX XXXX XXXX XXXX'
                      : 'Test Card: 4111 2222 3333 4444',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.credit_card),
                ),
                validator: (value) {
                  if (value == null || value.replaceAll(' ', '').length < 15) {
                    return 'Enter a valid 16-digit card number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiryController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                        CardExpiryFormatter(),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Expiry Date',
                        hintText: 'MM/YY',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.date_range),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 5) {
                          return 'Invalid expiry (MM/YY)';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _cvvController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'CVV / CVC',
                        hintText: '123',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 3) {
                          return 'Invalid CVV';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _processPayment,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Pay via ${_getGatewayName(_selectedGateway)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(' ', '');
    if (text.length > 16) text = text.substring(0, 16);
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && i + 1 != text.length) {
        buffer.write(' ');
      }
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class CardExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll('/', '');
    if (text.length > 4) text = text.substring(0, 4);
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 1 && text.length > 2) {
        buffer.write('/');
      }
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
