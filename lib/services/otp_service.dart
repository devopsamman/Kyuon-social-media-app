import 'package:supabase_flutter/supabase_flutter.dart';

class OTPService {
  final SupabaseClient _client = Supabase.instance.client;

  // Send OTP to email via Supabase
  Future<Map<String, dynamic>> sendOTP({
    required String email,
    int codeLength = 6,
  }) async {
    try {
      print('📧 Sending OTP to email: $email');

      // Send OTP via Supabase Auth
      await _client.auth.signInWithOtp(email: email.trim().toLowerCase());

      print('✅ OTP sent successfully to $email');

      return {
        'success': true,
        'email': email.trim().toLowerCase(),
        'message': 'OTP sent to your email. Please check your inbox.',
      };
    } catch (e) {
      print('❌ Error sending OTP: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Verify OTP code with Supabase
  Future<Map<String, dynamic>> verifyOTP({
    required String email,
    required String code,
    String? messageId,
  }) async {
    try {
      print('🔍 Verifying OTP for email: $email with code: $code');

      // Verify OTP with Supabase Auth
      final response = await _client.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: code.trim(),
        type: OtpType.email,
      );

      if (response.session != null) {
        print('✅ OTP verified successfully');
        return {
          'success': true,
          'verified': true,
          'user_id': response.user?.id,
        };
      } else {
        return {'success': false, 'error': 'Invalid OTP code'};
      }
    } catch (e) {
      print('❌ Error verifying OTP: $e');
      return {'success': false, 'error': 'Invalid or expired OTP code'};
    }
  }

  // Resend OTP
  Future<Map<String, dynamic>> resendOTP({
    required String email,
    int codeLength = 6,
  }) async {
    return await sendOTP(email: email, codeLength: codeLength);
  }
}
