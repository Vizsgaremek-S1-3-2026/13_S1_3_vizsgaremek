// lib/services/email_template.dart

class EmailTemplate {
  static const String subject = 'cQuizy - Email Cím Megerősítése';

  static String getHtmlBody(String code, String name) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body {
      padding: 0;
      margin: 0;
      background-color: #ffffff;
      font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
    }
    .wrapper {
      max-width: 600px;
      margin: 0 auto;
      background-color: #ffffff;
    }
    .top-pink-band {
      background-color: #ED2F5B;
      height: 140px;
      width: 100%;
      border-radius: 0 0 50% 50% / 0 0 25px 25px;
    }
    .logo-container {
      text-align: center;
      margin-top: 30px;
      margin-bottom: 40px;
    }
    .logo-img {
      width: 130px;
      height: auto;
    }
    .main-content {
      padding: 0 40px 40px 40px;
      text-align: center;
      color: #333333;
    }
    .greeting {
      font-size: 24px;
      font-weight: bold;
      margin-bottom: 25px;
      color: #333;
    }
    .description {
      font-size: 16px;
      color: #555555;
      line-height: 1.6;
      margin-bottom: 40px;
    }
    .code-box {
      background-color: #ffffff;
      color: #ED2F5B !important;
      display: inline-block;
      padding: 18px 40px;
      border-radius: 15px;
      font-size: 32px;
      font-weight: bold;
      letter-spacing: 12px;
      text-decoration: none;
      margin-bottom: 60px;
      border: 3px dashed #ED2F5B;
    }
    .features-container {
      margin-bottom: 50px;
    }
    .feature-table {
      width: 100%;
      border-collapse: collapse;
    }
    .feature-col {
      width: 33.33%;
      padding: 0 15px;
      vertical-align: top;
      text-align: center;
    }
    .feature-icon-box {
      height: 50px;
      display: flex;
      align-items: center;
      justify-content: center;
      margin-bottom: 12px;
    }
    .feature-icon {
      font-size: 34px;
    }
    .feature-title {
      font-size: 17px;
      font-weight: bold;
      color: #333;
      margin-bottom: 10px;
    }
    .feature-desc {
      font-size: 13px;
      color: #888;
      line-height: 1.5;
    }
    .footer {
      padding: 40px 30px;
      background-color: #f9f9f9;
      text-align: center;
      font-size: 13px;
      color: #aaaaaa;
      border-top: 1px solid #f0f0f0;
    }
    .footer-links {
      margin-top: 15px;
      margin-bottom: 15px;
    }
    .footer-links a {
      color: #ED2F5B;
      text-decoration: none;
      margin: 0 10px;
      font-weight: 500;
    }
    .highlight {
      background-color: #fff176;
      padding: 1px 3px;
      font-weight: bold;
    }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="top-pink-band"></div>
    
    <div class="logo-container">
      <img src="cid:logo@cquizy.app" alt="cQuizy Logo" class="logo-img">
    </div>
 
    <div class="main-content">
      <div class="greeting">Kedves $name!</div>
      
      <div class="description">
        Köszönjük, hogy csatlakoztál a <span class="highlight">cQuizy</span> közösségéhez!<br><br>
        A <span class="highlight">cQuizy</span> egy innovatív oktatási alkalmazás, amely látványos és egyszerű felületet biztosít a digitális számonkérésekhez, ezzel megkönnyítve a tanárok és diákok mindennapjait.
      </div>
 
      <div class="code-box">
        $code
      </div>
 
      <div class="features-container">
        <table class="feature-table">
          <tr>
            <td class="feature-col">
              <div class="feature-icon-box"><span class="feature-icon">⚡</span></div>
              <div class="feature-title">Gyors Javítás</div>
              <div class="feature-desc">Automatikus kiértékelés másodpercek alatt.</div>
            </td>
            <td class="feature-col">
              <div class="feature-icon-box"><span class="feature-icon">🛡️</span></div>
              <div class="feature-title">Biztonságos</div>
              <div class="feature-desc">Beépített csalás elleni védelem.</div>
            </td>
            <td class="feature-col">
              <div class="feature-icon-box"><span class="feature-icon">🎨</span></div>
              <div class="feature-title">Modern Design</div>
              <div class="feature-desc">Élmény a használat tanárnak és diáknak.</div>
            </td>
          </tr>
        </table>
      </div>
    </div>
 
    <div class="footer">
      <div>&copy; 2026 <span style="font-weight: bold; color: #777;">cQuizy</span> Projekt. Minden jog fenntartva.</div>
      <div class="footer-links">
        <a href="#">Facebook</a> &bull; <a href="#">Instagram</a> &bull; <a href="#">Adatvédelem</a>
      </div>
      <div>Önt azért kapta ezt az üzenetet, mert regisztrált a <span style="font-weight: bold; color: #777;">cQuizy</span> alkalmazásba.</div>
    </div>
  </div>
</body>
</html>
''';
  }
 
  static String getTextBody(String code, String name) {
    return '''
Üdvözlünk, $name a cQuizy közösségében!
 
Köszönjük, hogy csatlakoztál hozzánk! A cQuizy egy innovatív oktatási alkalmazás, amely megkönnyíti a tanárok és diákok mindennapjait.
 
A regisztrációs kódod: $code
 
Hitelesítsd magad az alkalmazásban a regisztráció befejezéséhez.
 
Üdvözlettel:
cQuizy Team
''';
  }
}
