import 'package:flutter/material.dart';
import '../services/subscription_service.dart';
import '../screens/subscription_screen.dart';

class FeatureGate extends StatelessWidget {
  final String requiredPlan; // 'free', 'premium', or 'family'
  final Widget child;
  final String featureName;

  const FeatureGate({
    super.key,
    required this.requiredPlan,
    required this.child,
    required this.featureName,
  });

  bool _hasAccess(String currentPlan, String required) {
    if (required == 'free') return true;
    if (required == 'premium') {
      return currentPlan == 'premium' || currentPlan == 'family';
    }
    if (required == 'family') {
      return currentPlan == 'family';
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final SubscriptionService subscriptionService = SubscriptionService();

    return FutureBuilder<String>(
      future: subscriptionService.getCurrentPlan(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: Text(featureName),
              backgroundColor: Colors.purple.shade700,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        String currentPlan = snapshot.data ?? 'free';

        if (_hasAccess(currentPlan, requiredPlan)) {
          return child;
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(featureName),
            backgroundColor: Colors.purple.shade700,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 80,
                    color: Colors.purple.shade300,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '$featureName is Locked',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'This security feature requires the ${requiredPlan.toUpperCase()} tier or higher. Upgrade your subscription to unlock remote controls and advanced protection capabilities.',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SubscriptionScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Upgrade Plan Now',
                        style: TextStyle(
                          color: Colors.white,
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
      },
    );
  }
}
