import 'package:flutter/material.dart';

import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import '../../../../common/services/auth_service.dart';
import '../../../../l10n/app_localizations.dart';

/// Forgot Password Screen
///
/// Handles password reset functionality.
/// Layout matches Customer-ForgotPassword.dc.html artboard (Wave 1.5 b5).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AuthService.resetPassword(
        email: _emailController.text.trim(),
      );

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(_getLocalizedErrorMessage(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getLocalizedErrorMessage(String error) {
    final l10n = AppLocalizations.of(context)!;
    if (error.contains('User not found') ||
        error.contains('invalid_credentials')) {
      return l10n.forgotPasswordErrorUserNotFound;
    } else if (error.contains('Too many requests') ||
        error.contains('rate_limit')) {
      return l10n.forgotPasswordErrorTooManyRequests;
    } else if (error.contains('SocketException') ||
        error.contains('Failed host lookup') ||
        error.contains('เชื่อมต่อ')) {
      return l10n.forgotPasswordErrorCannotConnect;
    }
    return l10n.forgotPasswordErrorGeneric;
  }

  void _showErrorDialog(String message) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JdcRadius.card)),
        icon: Icon(Icons.error_outline, color: jdc.danger, size: 48),
        title: Text(
          l10n.forgotPasswordErrorDialogTitle,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: jdc.cta,
                foregroundColor: jdc.onCta,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(JdcRadius.small)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(l10n.commonOk,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final isMockMode = AuthService.isMockMode;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JdcRadius.card)),
        icon: Icon(Icons.mark_email_read, color: jdc.cta, size: 48),
        title: Text(
          l10n.forgotPasswordSuccessTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          isMockMode
              ? l10n.forgotPasswordSuccessBodyMock(email)
              : l10n.forgotPasswordSuccessBody(email),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (!mounted) return;
                if (Navigator.of(this.context).canPop()) {
                  Navigator.of(this.context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: jdc.cta,
                foregroundColor: jdc.onCta,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(JdcRadius.small)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(l10n.forgotPasswordSuccessGoToLogin,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: jdc.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── back button ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    foregroundColor: jdc.text,
                    minimumSize: const Size(44, 44),
                  ),
                  icon: const Icon(Icons.chevron_left, size: 26),
                  tooltip: l10n.forgotPwdBackToLogin,
                ),
              ),
            ),

            // ── scrollable content ────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(28, 8, 28, 28 + bottomInset),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // lock icon box
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: jdc.brandSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.lock_outline,
                            size: 32,
                            color: jdc.brandOnSoft,
                          ),
                        ),

                        const SizedBox(height: JdcSpacing.xxl),

                        // title
                        Text(
                          l10n.forgotPasswordTitle,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: jdc.text,
                            fontVariations: const [FontVariation('wght', 700)],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // description
                        Text(
                          l10n.forgotPwdDescription,
                          style: TextStyle(
                            fontSize: 14,
                            color: jdc.muted,
                            height: 1.8,
                          ),
                        ),

                        const SizedBox(height: JdcSpacing.xxl),

                        // input field
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.forgotPwdIdentifierLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: jdc.text,
                                fontVariations: const [
                                  FontVariation('wght', 700)
                                ],
                              ),
                            ),
                            const SizedBox(height: 7),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: TextStyle(
                                  fontSize: 15, color: jdc.text),
                              decoration: InputDecoration(
                                hintText: l10n.forgotPwdIdentifierHint,
                                hintStyle:
                                    TextStyle(color: jdc.muted, fontSize: 15),
                                filled: true,
                                fillColor: jdc.paper,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 0),
                                constraints: const BoxConstraints(
                                    minHeight: JdcTouch.field),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      JdcRadius.field),
                                  borderSide: BorderSide(color: jdc.line),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      JdcRadius.field),
                                  borderSide:
                                      BorderSide(color: jdc.cta, width: 1.5),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      JdcRadius.field),
                                  borderSide: BorderSide(color: jdc.danger),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      JdcRadius.field),
                                  borderSide:
                                      BorderSide(color: jdc.danger, width: 1.5),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return l10n.forgotPasswordEmailRequired;
                                }
                                if (!value.contains('@')) {
                                  return l10n.forgotPasswordEmailInvalid;
                                }
                                return null;
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: JdcSpacing.xxl),

                        // teal info box
                        Container(
                          padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
                          decoration: BoxDecoration(
                            color: jdc.infoSoft,
                            borderRadius:
                                BorderRadius.circular(JdcRadius.field),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline,
                                  size: 18, color: jdc.infoInk),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l10n.forgotPwdInfoHint,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: jdc.infoInk,
                                    height: 1.7,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: JdcSpacing.xxl),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── bottom buttons ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // primary CTA
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _resetPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: jdc.cta,
                        foregroundColor: jdc.onCta,
                        disabledBackgroundColor:
                            jdc.cta.withValues(alpha: 0.5),
                        disabledForegroundColor:
                            jdc.onCta.withValues(alpha: 0.7),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(JdcRadius.field),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: jdc.onCta,
                              ),
                            )
                          : Text(
                              l10n.forgotPwdSendLink,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // back to login button
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: jdc.text,
                        side: BorderSide(color: jdc.line),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(JdcRadius.field),
                        ),
                      ),
                      child: Text(
                        l10n.forgotPwdBackToLogin,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
