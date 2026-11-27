"""앱 화면(raw_<lang>/0..5.png, 1080x1920) 위에 문구를 얹어 플레이 휴대전화 스크린샷(1080x1920 JPEG)을 만든다."""
import os
from PIL import Image, ImageDraw, ImageFont
F = r"E:\WonderWheel\Apps\MyChildTemperament\aigyeol\app\assets\fonts"
W = r"C:\Windows\Fonts"
FONT = {"ko": os.path.join(F, "Gaegu-Bold.ttf"), "en": os.path.join(F, "Gaegu-Bold.ttf"), "es": os.path.join(F, "PatrickHand-Regular.ttf"), "vi": os.path.join(F, "PatrickHand-Regular.ttf"),
        "ja": os.path.join(W, "YuGothB.ttc"), "zh": os.path.join(W, "msyhbd.ttc"), "zh-Hant": os.path.join(W, "msjhbd.ttc")}
CAP = {
 "ko": [("우리 아이의 MBTI는?", "기질검사와 성격검사를 한 번에"), ("16가지 유형", "아이마다 다른 캐릭터"), ("전문기관 수준의", "정밀 리포트"), ("엄마와 아빠의 답을", "나란히 비교해요"), ("형제자매", "기질 궁합"), ("기질에 맞춘", "오늘의 미션")],
 "en": [("What's your child's MBTI?", "Temperament + personality test"), ("16 types", "A character for every child"), ("Detailed report", "At a professional level"), ("Compare answers", "From Mom and Dad"), ("Siblings", "Temperament match"), ("Daily missions", "Made for your child's temperament")],
 "ja": [("わが子のMBTIは？", "気質検査・性格検査をまとめて"), ("16タイプ", "子どもごとのキャラクター"), ("専門機関レベルの", "詳しいレポート"), ("ママとパパの回答を", "並べて比較"), ("きょうだいの", "気質の相性"), ("気質に合わせた", "今日のミッション")],
 "zh": [("我家孩子的MBTI是？", "气质测评 + 性格测评"), ("16种类型", "每个孩子都有专属角色"), ("专业机构水准的", "详细报告"), ("妈妈和爸爸的回答", "并排对比"), ("兄弟姐妹的", "气质合拍度"), ("按气质定制的", "今日任务")],
 "zh-Hant": [("我家孩子的MBTI是？", "氣質測評 + 性格測評"), ("16種類型", "每個孩子都有專屬角色"), ("專業機構水準的", "詳細報告"), ("媽媽和爸爸的回答", "並排對比"), ("兄弟姊妹的", "氣質合拍度"), ("依氣質量身打造的", "今日任務")],
 "es": [("¿Cuál es el MBTI de tu peque?", "Test de temperamento y personalidad"), ("16 tipos", "Un personaje para cada peque"), ("Informe detallado", "De nivel profesional"), ("Compara respuestas", "De mamá y papá"), ("Hermanos", "Afinidad de temperamento"), ("Misiones diarias", "Según su temperamento")],
 "vi": [("MBTI của con là gì?", "Kiểm tra khí chất và tính cách"), ("16 loại", "Mỗi bé một nhân vật"), ("Báo cáo chi tiết", "Chuẩn chuyên gia"), ("So sánh câu trả lời", "Của bố và mẹ"), ("Anh chị em", "Hợp nhau thế nào"), ("Nhiệm vụ mỗi ngày", "Hợp khí chất của con")],
}
BG, INK, ACC, LINE = (251, 245, 234), (54, 64, 90), (45, 108, 152), (62, 70, 92)
def fit(draw, text, path, size, maxw):
    while True:
        f = ImageFont.truetype(path, size)
        if draw.textlength(text, font=f) <= maxw or size < 30: return f
        size -= 2
def make(lang, out):
    os.makedirs(out, exist_ok=True)
    for i, (a, b) in enumerate(CAP[lang]):
        c = Image.new("RGB", (1080, 1920), BG); d = ImageDraw.Draw(c)
        big = 92 if lang in ("ko", "en", "es", "vi") else 78
        fa = fit(d, a, FONT[lang], big, 980); fb = fit(d, b, FONT[lang], int(big * .72), 980)
        d.text((540, 120), a, font=fa, fill=INK, anchor="mm"); d.text((540, 228), b, font=fb, fill=ACC, anchor="mm")
        shot = Image.open(f"raw_{lang}/{i}.png").convert("RGB")
        h = 1920 - 330 - 50; w = round(h * 1080 / 1920)
        shot = shot.resize((w, h), Image.LANCZOS)
        m = Image.new("L", (w, h), 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, w - 1, h - 1), 44, fill=255)
        x = (1080 - w) // 2; y = 330
        d.rounded_rectangle((x - 8, y - 8, x + w + 7, y + h + 7), 52, fill=LINE)
        c.paste(shot, (x, y), m)
        c.save(f"{out}/{i + 1}.jpg", quality=90)
if __name__ == "__main__":
    for l in CAP: make(l, f"out_{l}")
