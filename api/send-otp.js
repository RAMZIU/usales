// api/send-otp.js
const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  host: 'alboraq.genious.net',
  port: 465,
  secure: true,
  auth: {
    user: 'notifications@uexpress.ma',
    pass: 'GKci0@ux2025',
  },
  tls: {
    rejectUnauthorized: false
  }
});

// Exporter pour Vercel (CommonJS)
module.exports = async (req, res) => {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { email, otp, name } = req.body;

    if (!email || !otp || !name) {
      return res.status(400).json({ error: 'Email, OTP et Name requis' });
    }

    console.log(`📧 Envoi OTP à ${email}...`);

    await transporter.sendMail({
      from: '"USALES Support" <notifications@uexpress.ma>',
      to: email,
      subject: '🔐 Code de vérification USALES',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; background: #f5f7fa; padding: 20px; }
            .container { max-width: 500px; margin: 0 auto; background: white; border-radius: 16px; padding: 30px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
            .logo { background: #06616E; color: white; padding: 10px 20px; border-radius: 12px; display: inline-block; font-weight: bold; font-size: 24px; }
            .otp-code { font-size: 48px; font-weight: bold; color: #06616E; text-align: center; letter-spacing: 8px; padding: 20px; background: #f0f7f8; border-radius: 12px; margin: 20px 0; }
            .warning { background: #fff3cd; padding: 12px; border-radius: 8px; color: #856404; font-size: 14px; margin: 15px 0; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="logo">USALES</div>
            <h2 style="color: #06616E;">Bonjour ${name} !</h2>
            <p>Votre code de vérification :</p>
            <div class="otp-code">${otp}</div>
            <p style="text-align: center; color: #666;">Ce code est valable <strong>5 minutes</strong>.</p>
            <div class="warning">⚠️ Si vous n'êtes pas à l'origine de cette demande, ignorez cet email.</div>
            <p style="text-align: center; color: #999; font-size: 12px;">USALES - Application de pilotage</p>
          </div>
        </body>
        </html>
      `,
    });

    console.log(`✅ Email envoyé à ${email}`);
    return res.status(200).json({ 
      success: true, 
      message: 'Email envoyé avec succès' 
    });

  } catch (error) {
    console.error('❌ Erreur:', error);
    return res.status(500).json({ 
      error: error.message || 'Erreur lors de l\'envoi' 
    });
  }
};