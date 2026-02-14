import nodemailer from "nodemailer";

// Create a reusable transporter object using Ethereal (dev-only, fully free)
let testAccount = await nodemailer.createTestAccount();

const transporter = nodemailer.createTransport({
  host: testAccount.smtp.host,
  port: testAccount.smtp.port,
  secure: testAccount.smtp.secure,
  auth: {
    user: testAccount.user,
    pass: testAccount.pass,
  },
});

export async function sendOtpEmail(toEmail: string, otp: string, txnId: string) {
  const info = await transporter.sendMail({
    from: '"Cash Platform" <no-reply@yourdomain.com>',
    to: toEmail,
    subject: "Your OTP Code",
    text: `Your OTP for transaction ${txnId} is: ${otp}.`,
    html: `<b>Your OTP for transaction ${txnId} is: ${otp}</b>`,
  });

  console.log(`[EMAIL MOCK] Message sent: ${info.messageId}`);
  console.log(`[EMAIL MOCK] Preview URL: ${nodemailer.getTestMessageUrl(info)}`);

  return info.messageId;
}