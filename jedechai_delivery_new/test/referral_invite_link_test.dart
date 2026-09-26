import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/services/referral_invite_link.dart';

void main() {
  test('invite URL carries a normalized referral code', () {
    final url = ReferralInviteLink.build(' ref-ab12 ');
    expect(url.toString(),
        'https://jedechai-delivery.vercel.app/invite?code=REF-AB12');
    expect(ReferralInviteLink.codeFromUri(url), 'REF-AB12');
  });

  test('app invite URI is accepted and unrelated links are rejected', () {
    expect(
        ReferralInviteLink.codeFromUri(Uri.parse('jdc://invite?code=ref-ab12')),
        'REF-AB12');
    expect(
        ReferralInviteLink.codeFromUri(Uri.parse('jdc://evil?code=REF-AB12')),
        isNull);
    expect(
        ReferralInviteLink.codeFromUri(
            Uri.parse('https://other.example/invite?code=REF-AB12')),
        isNull);
    expect(
        ReferralInviteLink.codeFromUri(Uri.parse(
            'https://jedechai-delivery.vercel.app/invite?code=REF-AB12&code=EVIL')),
        isNull);
  });
}
