import nodemailer from 'nodemailer';

let transporter;

const hasSmtpConfig = () => {
  return Boolean(
    process.env.SMTP_HOST &&
    process.env.SMTP_PORT &&
    process.env.SMTP_USER &&
    process.env.SMTP_PASS
  );
};

const getTransporter = () => {
  if (!hasSmtpConfig()) return null;

  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: Number(process.env.SMTP_PORT),
      secure: Number(process.env.SMTP_PORT) === 465,
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });
  }

  return transporter;
};

export const sendOtpEmail = async ({ to, otp }) => {
  const activeTransporter = getTransporter();

  if (!activeTransporter) {
    console.warn('[OTP_EMAIL] SMTP is not configured. OTP email not sent.');
    return false;
  }

  const from = process.env.EMAIL_FROM || process.env.SMTP_USER;

  await activeTransporter.sendMail({
    from,
    to,
    subject: 'LegalMate OTP Verification Code',
    text: `Your LegalMate verification code is ${otp}. It expires in 10 minutes.`,
    html: `
      <div style="font-family: Arial, sans-serif; line-height: 1.5;">
        <h2>LegalMate Email Verification</h2>
        <p>Your OTP code is:</p>
        <p style="font-size: 24px; font-weight: bold; letter-spacing: 3px;">${otp}</p>
        <p>This code expires in 10 minutes.</p>
      </div>
    `,
  });

  return true;
};
