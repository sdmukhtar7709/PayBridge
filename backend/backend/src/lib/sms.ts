
export async function sendOtpSms(toPhone: string, otp: string, txnId: string) {
  // Mock implementation: logs OTP details, does not send SMS
  console.log(`[SMS MOCK] Would send to ${toPhone}: OTP ${otp} for transaction ${txnId}`);
  return "mock-sid";
}