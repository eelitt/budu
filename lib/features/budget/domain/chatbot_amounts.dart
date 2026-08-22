/// Matches [ChatbotResponseProcessor]: non-yes/no answers are halved for
/// biweekly first; yearly answers are then divided by 12.
double scaleChatbotAmount({
  required double value,
  bool isBiweekly = false,
  bool isYearly = false,
}) {
  var result = value;
  if (isBiweekly) result = result / 2;
  if (isYearly) result = result / 12;
  return result;
}
