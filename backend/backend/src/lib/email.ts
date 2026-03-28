import nodemailer from "nodemailer";

type MailTransport = nodemailer.Transporter;

let transporterPromise: Promise<MailTransport> | null = null;

async function getTransporter(): Promise<MailTransport> {
  if (transporterPromise) return transporterPromise;

  transporterPromise = (async () => {
    try {
      // Dev default: Ethereal account. This needs network access.
      const testAccount = await nodemailer.createTestAccount();
      return nodemailer.createTransport({
        host: testAccount.smtp.host,
        port: testAccount.smtp.port,
        secure: testAccount.smtp.secure,
        auth: {
          user: testAccount.user,
          pass: testAccount.pass,
        },
      });
    } catch (error) {
      // Fallback transport keeps API alive when DNS/network is unavailable.
      console.warn("[EMAIL MOCK] Ethereal unavailable, using local json transport.", error);
      return nodemailer.createTransport({ jsonTransport: true });
    }
  })();

  return transporterPromise;
}

export async function sendOtpEmail(toEmail: string, otp: string, txnId: string) {
  const transporter = await getTransporter();
  const info = await transporter.sendMail({
    from: '"Cash Platform" <no-reply@yourdomain.com>',
    to: toEmail,
    subject: "Your OTP Code",
    text: `Your OTP for transaction ${txnId} is: ${otp}.`,
    html: `<b>Your OTP for transaction ${txnId} is: ${otp}</b>`,
  });

  console.log(`[EMAIL MOCK] Message sent: ${info.messageId}`);
  const previewUrl = nodemailer.getTestMessageUrl(info);
  if (previewUrl) {
    console.log(`[EMAIL MOCK] Preview URL: ${previewUrl}`);
  }

  return info.messageId;
}