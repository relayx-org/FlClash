import '../l10n/l10n.dart';

const delayTimedOutValue = -1;

String delayFailureText(int delay, AppLocalizations appLocalizations) {
  return delay == delayTimedOutValue
      ? appLocalizations.timeout
      : appLocalizations.delayFailed;
}
