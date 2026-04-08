import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

/// Generic "Under Construction" placeholder screen.
/// Used for features not yet implemented.
class UnderConstructionScreen extends StatefulWidget {
  final String title;
  final String featureName;
  final IconData icon;
  final int sidebarIndex;

  const UnderConstructionScreen({
    super.key,
    required this.title,
    required this.featureName,
    required this.icon,
    this.sidebarIndex = 0,
  });

  @override
  State<UnderConstructionScreen> createState() => _UnderConstructionScreenState();
}

class _UnderConstructionScreenState extends State<UnderConstructionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _bounceAnim = Tween<double>(begin: 0, end: -12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _fadeAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      selectedIndex: widget.sidebarIndex,
      title: widget.title,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated icon
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _bounceAnim.value),
                    child: Opacity(
                      opacity: _fadeAnim.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primary.withOpacity(0.1),
                              AppTheme.infoBlue.withOpacity(0.1),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.icon,
                          size: 56,
                          color: AppTheme.primary.withOpacity(0.6),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

              // Construction icon
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrangeLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.warningOrange.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.construction_rounded, color: AppTheme.warningOrange, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'En construction',
                      style: TextStyle(
                        color: AppTheme.warningOrange,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                widget.featureName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 24,
                    ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 400,
                child: Text(
                  'Cette fonctionnalité est en cours de développement et sera disponible dans une prochaine mise à jour.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 15,
                        height: 1.6,
                      ),
                ),
              ),
              const SizedBox(height: 40),

              // Progress indicators
              SizedBox(
                width: 300,
                child: Column(
                  children: [
                    _ProgressRow(label: 'Design', progress: 0.9),
                    const SizedBox(height: 12),
                    _ProgressRow(label: 'Développement', progress: 0.4),
                    const SizedBox(height: 12),
                    _ProgressRow(label: 'Tests', progress: 0.1),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              OutlinedButton.icon(
                onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Retour au tableau de bord'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final double progress;

  const _ProgressRow({required this.label, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.secondaryText,
                ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppTheme.divider,
              valueColor: AlwaysStoppedAnimation(
                progress >= 0.8
                    ? AppTheme.successGreen
                    : (progress >= 0.4 ? AppTheme.warningOrange : AppTheme.infoBlue),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(progress * 100).toInt()}%',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
