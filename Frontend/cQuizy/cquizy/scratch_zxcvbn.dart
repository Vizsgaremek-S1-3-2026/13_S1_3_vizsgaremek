import 'package:zxcvbn/zxcvbn.dart';

void main() {
  var zxcvbn = Zxcvbn();
  try {
    var result = zxcvbn.evaluate('Password123!', userInputs: ['password', '123']);
    print('With userInputs: ${result.score}');
  } catch (e) {
    print(e);
  }
}
