const CONFIG = require('./config');
const nodemailer = require('nodemailer');

async function testEmail() {
  if (!CONFIG.GMAIL_USER || !CONFIG.GMAIL_APP_PASSWORD) {
    console.log('❌ 失敗：.env 檔案中未設定 GMAIL_USER 或 GMAIL_APP_PASSWORD');
    return;
  }

  console.log(`📧 準備使用信箱 ${CONFIG.GMAIL_USER} 發送測試郵件...`);

  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: CONFIG.GMAIL_USER,
      pass: CONFIG.GMAIL_APP_PASSWORD,
    },
  });

  const mailOptions = {
    from: CONFIG.GMAIL_USER,
    // 原本 signal.js 寫死的收件人
    to: 'bennytsai0711@gmail.com', 
    subject: `🚨 Hyper Alert (系統測試): 郵件回報功能驗證`,
    text: `哈囉 Benny！這是一封由自動交易機器人發出的測試信件。\n如果收到這封信，代表您的 SMTP 伺服器與 Gmail 金鑰設定完全正常！\n觸發時間: ${new Date().toLocaleString('zh-TW', { timeZone: 'Asia/Taipei', hour12: false })}`,
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    console.log(`✅ 郵件發送成功！`);
    console.log(`回傳訊息: ${info.response}`);
  } catch (error) {
    console.log(`❌ 郵件發送失敗！`);
    console.log(`錯誤原因: ${error.message}`);
  }
}

testEmail();
