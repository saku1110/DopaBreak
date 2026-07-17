from pathlib import Path
import textwrap


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output" / "mockups" / "lifefocus_v2"
OUT.mkdir(parents=True, exist_ok=True)
for pattern in ("*.html", "*.png", "*.gif", "*.mp4"):
    for stale in OUT.glob(pattern):
        stale.unlink()


FONT_LINKS = """<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&family=Zen+Kaku+Gothic+New:wght@400;500;700;900&display=swap" rel="stylesheet">"""


CSS = r"""
:root{
  --bg:#0A0B0D;
  --bg2:#101216;
  --card:#14171C;
  --ink:#F4F5F2;
  --muted:#7E8694;
  --line:rgba(255,255,255,.08);
  --accent:#C7F94D;
  --accent-dim:rgba(199,249,77,.14);
  --danger:#FF6B5A;
}
*{margin:0;padding:0;box-sizing:border-box;-webkit-font-smoothing:antialiased;text-rendering:geometricPrecision;}
html,body{width:402px;height:874px;overflow:hidden;}
body{
  background:#0A0B0D;
  color:var(--ink);
  font-family:'Zen Kaku Gothic New','Space Grotesk',sans-serif;
}
.screen{width:402px;height:874px;padding:0 26px;display:flex;flex-direction:column;position:relative;overflow:hidden;}
.screen::before{content:"";position:absolute;inset:0;background:linear-gradient(180deg, rgba(255,255,255,.035), transparent 34%, rgba(255,255,255,.018));pointer-events:none;}
.screen>*{position:relative;z-index:1;}
.status{height:54px;display:flex;align-items:flex-end;justify-content:space-between;padding-bottom:6px;color:var(--ink);font-family:'Space Grotesk';font-weight:600;font-size:15px;letter-spacing:.02em;flex:0 0 54px;}
.status .r{display:flex;gap:6px;align-items:center;}
.status svg{display:block;color:var(--ink);}
.home{position:absolute;left:50%;transform:translateX(-50%);bottom:9px;width:134px;height:5px;border-radius:3px;background:rgba(255,255,255,.32);z-index:3;}
.tag{font-family:'JetBrains Mono';font-size:11px;letter-spacing:.34em;color:var(--muted);text-transform:uppercase;white-space:nowrap;}
.mono{font-family:'JetBrains Mono';letter-spacing:.28em;text-transform:uppercase;color:var(--muted);}
.num,.latin{font-family:'Space Grotesk';letter-spacing:-.02em;}
.page{flex:1;display:flex;flex-direction:column;padding-top:34px;}
.page.tight{padding-top:20px;}
.title{font-size:32px;line-height:1.2;font-weight:900;letter-spacing:.01em;}
.title.large{font-size:40px;line-height:1.14;}
.title.mid{font-size:28px;line-height:1.24;}
.subtitle{margin-top:14px;color:var(--muted);font-size:16px;line-height:1.55;font-weight:500;}
.card{background:var(--card);border:1px solid var(--line);border-radius:18px;}
.btn{height:58px;border-radius:16px;display:flex;align-items:center;justify-content:center;font-size:17px;font-weight:700;letter-spacing:.04em;text-decoration:none;}
.btn.primary{background:var(--accent);color:#0A0B0D;}
.btn.ghost{margin-top:11px;background:transparent;border:1px solid var(--line);color:var(--muted);font-weight:500;}
.bottom-actions{margin-top:auto;padding-bottom:40px;}
.link-ghost{margin-top:15px;text-align:center;color:var(--muted);font-size:14px;font-weight:500;}
.choice-list{display:flex;flex-direction:column;gap:12px;margin-top:27px;}
.choice{height:58px;padding:0 16px;display:flex;align-items:center;justify-content:space-between;background:var(--card);border:1px solid var(--line);border-radius:16px;font-size:16px;font-weight:700;}
.choice .check{width:22px;height:22px;border-radius:50%;border:1px solid rgba(255,255,255,.16);display:flex;align-items:center;justify-content:center;}
.choice.selected{border-color:var(--accent);background:linear-gradient(180deg, rgba(199,249,77,.09), rgba(199,249,77,.025));}
.choice.selected .check{background:var(--accent);border-color:var(--accent);color:#0A0B0D;font-family:'Space Grotesk';font-weight:700;font-size:13px;}
.note{color:var(--muted);font-size:13px;line-height:1.6;}
.top-row{display:flex;align-items:center;justify-content:space-between;}
.pill{border:1px solid var(--line);border-radius:999px;padding:7px 10px;color:var(--muted);font-size:12px;font-weight:700;}
.pill.active{background:var(--accent);border-color:var(--accent);color:#0A0B0D;}
.section-label{font-family:'JetBrains Mono';font-size:10.5px;letter-spacing:.26em;text-transform:uppercase;color:var(--muted);}
.goal-card{padding:20px;border-top:1px solid var(--line);border-bottom:1px solid var(--line);}
.goal-card.box{border:1px solid var(--line);border-radius:18px;background:var(--card);}
.goal-k{font-family:'JetBrains Mono';font-size:10.5px;letter-spacing:.28em;text-transform:uppercase;color:var(--muted);display:flex;align-items:center;gap:8px;}
.goal-k::before{content:"";width:6px;height:6px;border-radius:50%;background:var(--accent);display:inline-block;flex:0 0 6px;}
.goal-v{margin-top:12px;font-size:24px;line-height:1.35;font-weight:900;letter-spacing:.01em;}
.tabbar{position:absolute;left:18px;right:18px;bottom:20px;height:72px;border:1px solid var(--line);border-radius:22px;background:rgba(20,23,28,.92);display:grid;grid-template-columns:repeat(4,1fr);align-items:center;padding:7px 8px 9px;z-index:4;backdrop-filter:blur(16px);}
.tabitem{height:54px;border-radius:16px;color:var(--muted);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:5px;font-family:'JetBrains Mono';font-size:9px;letter-spacing:.08em;text-decoration:none;}
.tabitem.active{color:var(--accent);background:rgba(199,249,77,.055);}
.tabitem svg{width:21px;height:21px;stroke:currentColor;fill:none;stroke-width:1.6;stroke-linecap:round;stroke-linejoin:round;}
.with-tab{padding-bottom:105px;}
.divider{height:1px;background:var(--line);}
.app-grid{display:grid;grid-template-columns:repeat(2,1fr);gap:12px;margin-top:24px;}
.app-card{height:104px;padding:14px;background:var(--card);border:1px solid var(--line);border-radius:18px;display:flex;flex-direction:column;justify-content:space-between;}
.app-top{display:flex;align-items:center;justify-content:space-between;}
.app-symbol{width:34px;height:34px;border-radius:50%;border:1px solid rgba(255,255,255,.14);display:flex;align-items:center;justify-content:center;color:var(--ink);font-family:'Space Grotesk';font-size:14px;font-weight:700;}
.app-name{font-size:14px;font-weight:700;}
.toggle{width:40px;height:24px;border-radius:999px;background:rgba(255,255,255,.08);position:relative;border:1px solid var(--line);}
.toggle::after{content:"";position:absolute;width:18px;height:18px;border-radius:50%;left:3px;top:2px;background:var(--muted);}
.toggle.on{background:var(--accent-dim);border-color:rgba(199,249,77,.44);}
.toggle.on::after{left:17px;background:var(--accent);}
.field{padding:18px;margin-top:16px;background:var(--card);border:1px solid var(--line);border-radius:18px;}
.field .value{margin-top:12px;font-weight:900;line-height:1.35;}
.field.big .value{font-size:25px;}
.field.medium .value{font-size:19px;color:var(--ink);}
.mode-card{padding:18px 18px 17px;margin-top:13px;border:1px solid var(--line);border-radius:18px;background:var(--card);}
.mode-card.selected{border-color:var(--accent);background:linear-gradient(180deg, rgba(199,249,77,.09), rgba(199,249,77,.025));}
.mode-card h3{font-size:18px;line-height:1.25;font-weight:900;}
.mode-card p{margin-top:8px;color:var(--muted);font-size:13.5px;line-height:1.48;}
.mini-badge{display:inline-flex;align-items:center;border-radius:999px;background:rgba(199,249,77,.12);border:1px solid rgba(199,249,77,.35);color:var(--accent);font-family:'JetBrains Mono';font-size:9px;letter-spacing:.16em;padding:4px 7px;text-transform:uppercase;}
.flow{margin-top:23px;display:flex;flex-direction:column;align-items:center;}
.flow-step{width:100%;padding:16px;background:var(--card);border:1px solid var(--line);border-radius:18px;display:grid;grid-template-columns:46px 1fr;gap:13px;align-items:center;}
.flow-icon{width:46px;height:46px;border-radius:50%;border:1px solid rgba(255,255,255,.12);display:flex;align-items:center;justify-content:center;font-family:'Space Grotesk';font-weight:700;color:var(--ink);}
.flow-copy h3{font-size:16px;font-weight:900;}
.flow-copy p{margin-top:5px;color:var(--muted);font-size:12.5px;line-height:1.45;}
.connector{width:2px;height:28px;background:var(--accent);opacity:.8;}
.shield-icon{width:118px;height:118px;margin:42px auto 26px;display:block;color:var(--accent);}
.widget-preview{margin:28px auto 24px;width:244px;height:306px;border-radius:30px;background:linear-gradient(180deg,#171A1F,#090A0C);border:1px solid var(--line);padding:22px 18px;text-align:center;}
.widget-preview .clock{font-family:'Space Grotesk';font-size:44px;font-weight:600;letter-spacing:-.04em;}
.mini-widget-card{margin-top:30px;border:1px solid rgba(199,249,77,.45);border-radius:18px;background:rgba(20,23,28,.86);padding:16px 14px;}
.mini-widget-card .goal-v{font-size:18px;line-height:1.32;}
.mini-widget-grid{margin-top:26px;display:grid;grid-template-columns:1fr 1fr;gap:8px;}
.mini-widget-chip{height:38px;border-radius:14px;border:1px solid rgba(199,249,77,.4);background:rgba(20,23,28,.86);display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:900;}
.mini-widget-chip.wide{grid-column:1 / -1;margin:0 28px;}
.widget-scale-demo{margin-top:20px;display:flex;flex-direction:column;gap:10px;}
.widget-single-demo{height:48px;border-radius:16px;border:1px solid rgba(199,249,77,.52);background:rgba(199,249,77,.08);display:flex;align-items:center;justify-content:center;color:var(--accent);font-size:17px;font-weight:900;}
.widget-stack-demo{border-radius:16px;border:1px solid rgba(255,255,255,.12);background:rgba(20,23,28,.82);padding:10px 10px 11px;}
.widget-stack-demo .stack-main{height:28px;display:flex;align-items:center;justify-content:center;font-size:13px;font-weight:900;color:var(--ink);}
.widget-stack-demo .stack-row{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:7px;}
.widget-stack-demo .stack-sub{height:25px;border-radius:10px;background:rgba(255,255,255,.06);display:flex;align-items:center;justify-content:center;font-size:10.5px;font-weight:900;color:var(--muted);}
.steps{display:flex;flex-direction:column;gap:8px;margin-top:4px;color:var(--muted);font-size:14px;line-height:1.5;}
.center-stack{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;}
.success-mark{width:116px;height:76px;border-radius:18px;border:1px solid rgba(199,249,77,.42);background:rgba(199,249,77,.08);display:flex;align-items:center;justify-content:center;margin-bottom:26px;color:var(--accent);}
.metrics{margin-top:24px;display:grid;grid-template-columns:repeat(3,1fr);overflow:hidden;}
.metric{padding:16px 10px;border-right:1px solid var(--line);}
.metric:last-child{border-right:0;}
.metric .m-num{font-family:'Space Grotesk';font-size:25px;font-weight:700;letter-spacing:-.03em;}
.metric .m-label{margin-top:6px;font-size:11.5px;color:var(--muted);font-weight:700;line-height:1.35;}
.metric.accent .m-label{color:var(--accent);}
.bar-card{padding:17px;margin-top:16px;}
.bars{height:110px;margin-top:18px;display:flex;align-items:end;gap:13px;}
.bar{width:31px;border-radius:9px 9px 3px 3px;background:rgba(255,255,255,.12);}
.bar.active{background:var(--accent);}
.goal-hero{margin-top:25px;}
.goal-hero .section-label{margin-bottom:12px;}
.goal-hero .hero-text{font-size:31px;line-height:1.25;font-weight:900;letter-spacing:.01em;}
.edit-icon{width:30px;height:30px;border-radius:50%;border:1px solid var(--line);display:flex;align-items:center;justify-content:center;color:var(--muted);}
.list-card{margin-top:22px;overflow:hidden;}
.list-row{height:54px;display:flex;align-items:center;justify-content:space-between;padding:0 16px;border-bottom:1px solid var(--line);font-size:15px;font-weight:700;}
.list-row:last-child{border-bottom:0;}
.chev{color:var(--muted);font-family:'Space Grotesk';font-size:20px;}
.stats-big{margin-top:18px;font-family:'Space Grotesk';font-size:86px;line-height:1;font-weight:700;letter-spacing:-.06em;}
.stats-big + .subtitle{margin-top:4px;}
.heat{margin-top:23px;display:grid;grid-template-columns:58px 1fr;gap:10px 12px;align-items:center;}
.heat label{color:var(--muted);font-size:13px;font-weight:700;}
.heat-track{height:10px;border-radius:999px;background:rgba(255,255,255,.09);overflow:hidden;}
.heat-fill{height:100%;border-radius:inherit;background:rgba(255,255,255,.42);}
.heat-fill.accent{background:var(--accent);}
.reason-list{margin-top:18px;display:flex;flex-direction:column;gap:12px;}
.reason-row{display:grid;grid-template-columns:78px 1fr 38px;align-items:center;gap:10px;font-size:13px;color:var(--muted);}
.reason-track{height:6px;border-radius:999px;background:rgba(255,255,255,.08);overflow:hidden;}
.reason-fill{height:100%;background:rgba(255,255,255,.36);border-radius:inherit;}
.line-chart{margin-top:18px;height:96px;border-top:1px solid var(--line);border-bottom:1px solid var(--line);}
.intercept-meta{display:flex;align-items:center;justify-content:space-between;margin-top:24px;padding-bottom:28px;border-bottom:1px solid var(--line);}
.count{font-family:'JetBrains Mono';font-size:11px;letter-spacing:.12em;color:var(--muted);}
.count b{color:var(--accent);font-weight:500;}
.breath-only{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;padding-bottom:60px;}
.countdown-block{width:218px;border-radius:22px;border:1px solid rgba(255,255,255,.11);background:rgba(20,23,28,.82);padding:28px 24px 24px;margin-bottom:34px;text-align:center;}
.countdown-number{font-family:'Space Grotesk';font-size:84px;line-height:.9;font-weight:600;letter-spacing:-.05em;}
.countdown-bar{height:6px;border-radius:999px;background:rgba(255,255,255,.09);overflow:hidden;margin-top:24px;}
.countdown-bar span{display:block;height:100%;border-radius:inherit;background:var(--accent);}
.breath-title{font-size:23px;font-weight:900;letter-spacing:.06em;}
.breath-sub{margin-top:10px;font-family:'JetBrains Mono';font-size:11px;letter-spacing:.22em;color:var(--muted);}
.big-count{margin-top:22px;font-family:'Space Grotesk';font-size:92px;line-height:.96;font-weight:700;letter-spacing:-.06em;}
.chip-grid{display:grid;grid-template-columns:repeat(2,1fr);gap:12px;margin-top:28px;}
.chip{height:52px;border-radius:16px;border:1px solid var(--line);background:var(--card);display:flex;align-items:center;justify-content:center;font-weight:700;font-size:14px;}
.chip.selected{border-color:var(--accent);background:rgba(199,249,77,.1);color:var(--accent);}
.time-panel{width:226px;margin:40px auto 24px;border-radius:22px;border:1px solid rgba(255,255,255,.11);background:rgba(20,23,28,.82);padding:26px 22px 22px;text-align:center;}
.time-value{display:flex;align-items:flex-end;justify-content:center;gap:8px;}
.time-value span{font-family:'Space Grotesk';font-size:82px;line-height:.82;font-weight:700;letter-spacing:-.05em;}
.time-value small{color:var(--muted);font-size:19px;font-weight:900;padding-bottom:6px;}
.time-meter{height:7px;border-radius:999px;background:rgba(255,255,255,.09);overflow:hidden;margin-top:24px;}
.time-meter span{display:block;height:100%;border-radius:inherit;background:var(--accent);}
.time-pills{display:flex;justify-content:center;gap:10px;margin-top:3px;}
.time-pill{width:52px;height:36px;border-radius:999px;border:1px solid var(--line);display:flex;align-items:center;justify-content:center;font-family:'Space Grotesk';font-weight:700;color:var(--muted);}
.time-pill.active{background:var(--accent);border-color:var(--accent);color:#0A0B0D;}
.small-metric{margin-top:22px;height:58px;display:flex;align-items:center;justify-content:center;border:1px solid var(--line);border-radius:18px;background:var(--card);font-weight:900;}
.lock.screen{padding:0 20px;background:linear-gradient(180deg,#111419 0%,#08090B 48%,#050607 100%);}
.lock.screen::before{background:linear-gradient(180deg, rgba(255,255,255,.035), transparent 42%, rgba(255,255,255,.026));}
.lock-clock{text-align:center;font-family:'Space Grotesk';font-size:82px;font-weight:600;letter-spacing:-.065em;margin-top:96px;}
.lock-goal{margin-top:55px;border:1px solid rgba(199,249,77,.62);border-radius:24px;background:rgba(20,23,28,.66);padding:22px 20px 24px;text-align:center;}
.lock-goal .divider{margin:8px 0 24px;}
.lock-goal .lock-label{font-family:'JetBrains Mono';font-size:12px;letter-spacing:.22em;color:var(--muted);text-transform:uppercase;}
.lock-goal .lock-title{font-size:31px;line-height:1.28;font-weight:900;margin-top:18px;}
.lock-progress{margin:18px auto 0;width:34px;height:52px;border-radius:14px;background:rgba(199,249,77,.13);position:relative;}
.lock-progress::after{content:"";position:absolute;left:0;right:0;bottom:0;height:23px;background:var(--accent);border-radius:12px;}
.lock-goal-stack{margin-top:46px;display:grid;grid-template-columns:repeat(2,1fr);gap:10px;}
.lock-goal-chip{height:48px;border-radius:16px;border:1px solid rgba(255,255,255,.11);background:rgba(20,23,28,.74);display:flex;align-items:center;justify-content:center;text-align:center;font-size:14px;font-weight:900;line-height:1.15;backdrop-filter:blur(14px);}
.lock-goal-chip.primary{border-color:rgba(199,249,77,.62);color:var(--accent);background:rgba(199,249,77,.09);}
.lock-goal-chip.wide{grid-column:1 / -1;margin:0 54px;}
.lock-combo-widget{width:252px;margin:42px auto 0;border-radius:20px;border:1px solid rgba(199,249,77,.48);background:rgba(20,23,28,.68);padding:12px;backdrop-filter:blur(16px);box-shadow:0 18px 48px rgba(0,0,0,.28);}
.lock-combo-main{height:34px;border-radius:12px;background:rgba(199,249,77,.09);display:flex;align-items:center;justify-content:center;color:var(--accent);font-size:17px;font-weight:900;}
.lock-combo-row{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:8px;}
.lock-combo-sub{height:29px;border-radius:10px;background:rgba(255,255,255,.06);display:flex;align-items:center;justify-content:center;color:var(--ink);font-size:11.5px;font-weight:900;}
.lock-widget-note{margin-top:12px;text-align:center;color:var(--muted);font-family:'JetBrains Mono';font-size:10px;letter-spacing:.18em;text-transform:uppercase;}
.lock-stat-widget{width:150px;margin:32px auto 0;border-radius:18px;border:1px solid rgba(255,255,255,.12);background:rgba(20,23,28,.66);padding:13px 14px;text-align:left;}
.lock-stat-label{font-family:'JetBrains Mono';font-size:9px;letter-spacing:.16em;color:var(--muted);}
.lock-stat-value{margin-top:5px;font-family:'Space Grotesk';font-size:34px;line-height:1;font-weight:700;letter-spacing:-.04em;}
.lock-stat-caption{margin-top:3px;color:var(--muted);font-size:12px;font-weight:700;}
.lock-icons{position:absolute;left:58px;right:58px;bottom:67px;display:flex;justify-content:space-between;align-items:center;}
.lock-icon{width:52px;height:52px;border-radius:50%;background:rgba(20,23,28,.72);display:flex;align-items:center;justify-content:center;color:var(--ink);}
.home-wall.screen{padding:0 22px;background:linear-gradient(180deg,#111417 0%,#08090A 50%,#050607 100%);}
.home-wall.screen::before{background:linear-gradient(180deg, transparent 0%, rgba(255,255,255,.05) 100%);}
.widget-small{width:156px;height:156px;border-radius:25px;border:1px solid var(--line);background:rgba(20,23,28,.84);padding:18px;margin-top:60px;}
.widget-small .big{font-family:'Space Grotesk';font-size:56px;line-height:1;font-weight:700;letter-spacing:-.05em;}
.lime-dot{width:8px;height:8px;border-radius:50%;background:var(--accent);display:inline-block;}
.widget-medium{height:154px;border-radius:25px;border:1px solid var(--line);background:rgba(20,23,28,.84);padding:20px;margin-top:18px;display:grid;grid-template-columns:1fr 92px;align-items:center;gap:12px;}
.medium-goal{font-size:20px;line-height:1.35;font-weight:900;}
.mini-meter{display:flex;flex-direction:column;gap:10px;align-items:stretch;justify-content:center;font-family:'Space Grotesk';font-size:22px;font-weight:700;}
.mini-meter-track{height:7px;border-radius:999px;background:rgba(255,255,255,.1);overflow:hidden;}
.mini-meter-track span{display:block;height:100%;border-radius:inherit;background:var(--accent);}
.app-icons{margin-top:44px;display:grid;grid-template-columns:repeat(4,1fr);gap:26px 22px;}
.dummy-app{display:flex;flex-direction:column;align-items:center;gap:8px;color:rgba(244,245,242,.58);font-family:'JetBrains Mono';font-size:8px;letter-spacing:.1em;}
.dummy-app .app-tile{width:48px;height:48px;border-radius:15px;background:rgba(255,255,255,.1);border:1px solid rgba(255,255,255,.08);}
.benefits{margin-top:23px;padding:6px 0;}
.benefit{height:48px;display:grid;grid-template-columns:24px 1fr;align-items:center;gap:10px;color:var(--ink);font-size:15px;font-weight:700;border-bottom:1px solid var(--line);}
.benefit:last-child{border-bottom:0;}
.benefit .tick{color:var(--accent);font-family:'Space Grotesk';font-weight:700;}
.plans{display:flex;flex-direction:column;gap:10px;margin-top:17px;}
.plan{height:62px;padding:0 15px;border-radius:17px;border:1px solid var(--line);background:var(--card);display:flex;align-items:center;justify-content:space-between;}
.plan.selected{border-color:var(--accent);background:rgba(199,249,77,.08);}
.plan strong{font-size:16px;}
.plan .price{font-family:'Space Grotesk';font-size:18px;font-weight:700;}
.fine{margin-top:12px;text-align:center;color:var(--muted);font-size:11px;line-height:1.5;}
"""


STATUS = """
<div class="status">
  <span>9:41</span>
  <span class="r">
    <svg width="18" height="12" viewBox="0 0 18 12" aria-hidden="true"><g fill="currentColor"><rect x="0" y="7" width="3" height="5" rx="1"/><rect x="5" y="4" width="3" height="8" rx="1"/><rect x="10" y="1.5" width="3" height="10.5" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1"/></g></svg>
    <svg width="17" height="12" viewBox="0 0 17 12" fill="none" aria-hidden="true"><path d="M8.5 10.5a1.4 1.4 0 100 .01M3 6.2a8 8 0 0111 0M.7 3.4a12 12 0 0115.6 0" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>
    <svg width="26" height="13" viewBox="0 0 26 13" aria-hidden="true"><rect x="1" y="1" width="21" height="11" rx="3" fill="none" stroke="currentColor" stroke-opacity=".5"/><rect x="3" y="3" width="16" height="7" rx="1.5" fill="currentColor"/><rect x="23.5" y="4.5" width="1.6" height="4" rx="1" fill="currentColor" fill-opacity=".5"/></svg>
  </span>
</div>
"""


def icon(name: str) -> str:
    icons = {
        "home": '<path d="M3.5 10.5 10.5 4l7 6.5"/><path d="M5.5 9.5v8h10v-8"/>',
        "target": '<path d="M5 18V4"/><path d="M5 4h10.5l-2.2 3 2.2 3H5"/>',
        "stats": '<path d="M4 17V7"/><path d="M10.5 17V4"/><path d="M17 17v-9"/><path d="M2.5 17.5h16"/>',
        "settings": '<path d="M4 6h13"/><path d="M4 10.5h13"/><path d="M4 15h13"/><path d="M8 4.5v3"/><path d="M13 9v3"/><path d="M10 13.5v3"/>',
        "edit": '<svg width="15" height="15" viewBox="0 0 20 20" fill="none" aria-hidden="true"><path d="M4 14.8V17h2.2L15.8 7.4l-2.2-2.2L4 14.8Z" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/><path d="m12.8 6 2.2 2.2" stroke="currentColor" stroke-width="1.6"/></svg>',
    }
    if name in {"home", "target", "stats", "settings"}:
        return f'<svg viewBox="0 0 21 21" aria-hidden="true">{icons[name]}</svg>'
    return icons[name]


def tabbar(active: str) -> str:
    labels = [("home", "ホーム"), ("target", "目標"), ("stats", "統計"), ("settings", "設定")]
    return '<nav class="tabbar">' + "".join(
        f'<a class="tabitem {"active" if key == active else ""}">{icon(key)}<span>{label}</span></a>'
        for key, label in labels
    ) + "</nav>"


def home_indicator() -> str:
    return '<div class="home"></div>'


def html(title: str, body: str) -> str:
    return f"""<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=402, initial-scale=1">
{FONT_LINKS}
<title>{title}</title>
<style>
{CSS}
</style>
</head>
<body>
{body}
</body>
</html>
"""


def screen(name: str, inner: str, cls: str = "") -> str:
    return f'<div class="screen {cls}">{STATUS}{inner}{home_indicator()}</div>'


def write(name: str, title: str, inner: str, cls: str = ""):
    (OUT / f"{name}.html").write_text(html(title, screen(name, inner, cls)), encoding="utf-8")


write(
    "01_welcome",
    "LifeFocus - Welcome",
    """
    <main class="page" style="padding-top:45px;">
      <div class="tag">LIFEFOCUS</div>
      <div style="height:102px;margin-top:48px;display:flex;align-items:center;justify-content:center;">
        <svg width="132" height="72" viewBox="0 0 132 72" fill="none" aria-hidden="true">
          <path d="M24 58C33 28 55 13 88 13" stroke="rgba(255,255,255,.1)" stroke-width="2.2" stroke-linecap="round"/>
          <path d="M50 53C59 34 75 25 99 25" stroke="#C7F94D" stroke-width="2.4" stroke-linecap="round"/>
          <path d="M40 66H92" stroke="rgba(255,255,255,.08)" stroke-width="1"/>
        </svg>
      </div>
      <h1 class="title large">SNSを断ち、<br>人生を取り戻す。</h1>
      <p class="subtitle" style="width:298px;">開く前のひと呼吸が、あなたを目標に連れ戻す。</p>
      <div class="bottom-actions">
        <div class="btn primary">はじめる</div>
        <div class="link-ghost">すでに使ったことがある</div>
      </div>
    </main>
    """,
)

write(
    "02_self_check",
    "LifeFocus - Self Check",
    """
    <main class="page tight">
      <div class="tag">STEP 01 / 04</div>
      <h1 class="title mid" style="margin-top:24px;">1日に何回、無意識にSNSを開いていますか？</h1>
      <div class="choice-list">
        <div class="choice"><span>5回未満</span><span class="check"></span></div>
        <div class="choice selected"><span>5〜15回</span><span class="check">✓</span></div>
        <div class="choice"><span>15〜30回</span><span class="check"></span></div>
        <div class="choice"><span>30回以上</span><span class="check"></span></div>
      </div>
      <p class="note" style="margin-top:22px;">平均的な人は1日96回スマホを手に取ります。</p>
      <div class="bottom-actions"><div class="btn primary">次へ</div></div>
    </main>
    """,
)

write(
    "03_choose_apps",
    "LifeFocus - Choose Apps",
    """
    <main class="page tight">
      <div class="tag">STEP 02 / 04</div>
      <h1 class="title" style="margin-top:24px;">止めたいアプリを選ぶ</h1>
      <p class="subtitle">いつでも変更できます。</p>
      <div class="app-grid">
        <div class="app-card"><div class="app-top"><span class="app-symbol">X</span><span class="toggle on"></span></div><div class="app-name">X</div></div>
        <div class="app-card"><div class="app-top"><span class="app-symbol">◎</span><span class="toggle on"></span></div><div class="app-name">Instagram</div></div>
        <div class="app-card"><div class="app-top"><span class="app-symbol">♪</span><span class="toggle on"></span></div><div class="app-name">TikTok</div></div>
        <div class="app-card"><div class="app-top"><span class="app-symbol">▶</span><span class="toggle"></span></div><div class="app-name">YouTube</div></div>
        <div class="app-card"><div class="app-top"><span class="app-symbol">f</span><span class="toggle"></span></div><div class="app-name">Facebook</div></div>
        <div class="app-card"><div class="app-top"><span class="app-symbol">●</span><span class="toggle"></span></div><div class="app-name">LINE</div></div>
      </div>
      <div class="bottom-actions"><div class="btn primary">3つのアプリをブロック</div></div>
    </main>
    """,
)

write(
    "04_goal_setup",
    "LifeFocus - Goal Setup",
    """
    <main class="page tight">
      <div class="tag">STEP 03 / 04</div>
      <h1 class="title" style="margin-top:24px;">あなたの人生の<br>目標は？</h1>
      <p class="subtitle">開く前に毎回これを思い出します。</p>
      <div class="field big" style="margin-top:30px;">
        <div class="section-label">あなたの目標 / YOUR GOAL</div>
        <div class="value">英語で商談できる自分になる</div>
      </div>
      <div class="field medium">
        <div class="section-label">1年後の自分 / 1 YEAR</div>
        <div class="value">TOEIC 900 / 海外チームと働く</div>
      </div>
      <p class="note" style="margin-top:18px;">目標は短く、心が動く言葉で。</p>
      <div class="bottom-actions"><div class="btn primary">次へ</div></div>
    </main>
    """,
)

write(
    "05_choose_mode",
    "LifeFocus - Choose Mode",
    """
    <main class="page tight">
      <div class="tag">STEP 04 / 04</div>
      <h1 class="title" style="margin-top:24px;">どのくらい強く<br>止めますか？</h1>
      <div style="margin-top:24px;">
        <section class="mode-card selected">
          <div class="top-row"><h3>ディープフォーカス</h3><span class="mini-badge">BEST</span></div>
          <p>開くのに3秒呼吸＋意図確認＋時間制限。最も効果が高い。</p>
        </section>
        <section class="mode-card">
          <h3>スタンダード</h3>
          <p>ひと呼吸＋意図確認。毎日の反射に静かな余白を作ります。</p>
        </section>
        <section class="mode-card">
          <h3>ナイトオンリー</h3>
          <p>21時以降だけ強化。睡眠前のスクロールを止めます。</p>
        </section>
      </div>
      <div class="bottom-actions"><div class="btn primary">この設定で進む</div></div>
    </main>
    """,
)

write(
    "06_intervention_preview",
    "LifeFocus - Intervention Preview",
    """
    <main class="page tight">
      <div class="tag">PREVIEW</div>
      <h1 class="title mid" style="margin-top:24px;">SNSを開こうとすると、<br>こうなります</h1>
      <div class="flow">
        <section class="flow-step">
          <div class="flow-icon">3</div>
          <div class="flow-copy"><h3>ひと呼吸</h3><p>3秒だけ止まり、反射のまま開く流れを切ります。</p></div>
        </section>
        <div class="connector"></div>
        <section class="flow-step">
          <div class="flow-icon">目</div>
          <div class="flow-copy"><h3>目標を思い出す</h3><p>英語で商談できる自分になる、を開く前に表示。</p></div>
        </section>
        <div class="connector"></div>
        <section class="flow-step">
          <div class="flow-icon">分</div>
          <div class="flow-copy"><h3>意図を選ぶ</h3><p>開かないか、必要な時間だけ開くかを選びます。</p></div>
        </section>
      </div>
      <div class="bottom-actions"><div class="btn primary">なるほど、続ける</div></div>
    </main>
    """,
)

write(
    "07_permission",
    "LifeFocus - Permission",
    """
    <main class="page tight">
      <div class="tag">PERMISSION</div>
      <svg class="shield-icon" viewBox="0 0 120 120" fill="none" aria-hidden="true">
        <path d="M60 15 91 28v25c0 25-13 43-31 52-18-9-31-27-31-52V28l31-13Z" stroke="currentColor" stroke-width="2.2"/>
        <path d="M43 47h34v28H43V47Z" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round"/>
        <path d="M50 57h20M50 65h13" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>
      </svg>
      <h1 class="title mid" style="text-align:center;">スクリーンタイムへの<br>アクセスを許可</h1>
      <p class="subtitle" style="text-align:center;">アプリの起動を検知してブロックするために必要です。使用データは端末内に留まり、外部に送信されません。</p>
      <div class="bottom-actions">
        <div class="btn primary">許可する</div>
        <div class="btn ghost">あとで</div>
      </div>
    </main>
    """,
)

write(
    "08_widget_guide",
    "LifeFocus - Widget Guide",
    """
    <main class="page tight">
      <div class="tag">WIDGET</div>
      <h1 class="title" style="margin-top:24px;">ロック画面に<br>小さく並べる</h1>
      <p class="subtitle">短い目標をいくつか置いて、開く前に戻る先を思い出します。</p>
      <div class="widget-preview">
        <div class="clock">9:41</div>
        <div class="widget-scale-demo">
          <div class="widget-single-demo">深く集中</div>
          <div class="widget-stack-demo">
            <div class="stack-main">英語で話す</div>
            <div class="stack-row">
              <div class="stack-sub">深く集中</div>
              <div class="stack-sub">夜は見ない</div>
            </div>
          </div>
        </div>
      </div>
      <div class="steps">
        <div>1. ロック画面を長押し</div>
        <div>2. 小型ウィジェットを追加</div>
        <div>3. 置く目標を選ぶ</div>
      </div>
      <div class="bottom-actions">
        <div class="btn primary">小型ウィジェットを設定</div>
        <div class="btn ghost">スキップ</div>
      </div>
    </main>
    """,
)

write(
    "09_ready",
    "LifeFocus - Ready",
    """
    <main class="page tight">
      <div class="center-stack" style="padding-bottom:48px;">
        <div class="success-mark">
          <svg width="64" height="42" viewBox="0 0 64 42" fill="none" aria-hidden="true">
            <path d="M9 23 24 36 55 7" stroke="currentColor" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
        </div>
        <h1 class="title large">準備完了。</h1>
        <p class="subtitle" style="margin-top:12px;">今日から、開く前にひと呼吸。</p>
        <div class="goal-card box" style="width:100%;margin-top:28px;text-align:left;">
          <div class="goal-k">あなたの目標</div>
          <div class="goal-v">英語で商談できる自分になる</div>
        </div>
      </div>
      <div class="bottom-actions"><div class="btn primary">LifeFocusをはじめる</div></div>
    </main>
    """,
)

write(
    "10_home",
    "LifeFocus - Home",
    f"""
    <main class="page tight with-tab">
      <div class="top-row"><div class="tag">TODAY · 6月28日</div><div class="pill">12日連続</div></div>
      <section class="goal-hero">
        <div class="section-label">あなたの目標</div>
        <div class="hero-text">英語で商談できる自分になる</div>
      </section>
      <section class="card metrics">
        <div class="metric accent"><div class="m-num">14回</div><div class="m-label">開かなかった</div></div>
        <div class="metric"><div class="m-num">1:42</div><div class="m-label">節約</div></div>
        <div class="metric"><div class="m-num">18回</div><div class="m-label">試行</div></div>
      </section>
      <section class="card bar-card">
        <div class="top-row"><div class="section-label">今週の傾向</div><div class="note">82%</div></div>
        <div class="bars">
          <div class="bar" style="height:44px"></div><div class="bar" style="height:68px"></div><div class="bar" style="height:52px"></div><div class="bar" style="height:86px"></div><div class="bar" style="height:61px"></div><div class="bar active" style="height:98px"></div><div class="bar" style="height:73px"></div>
        </div>
      </section>
    </main>
    {tabbar("home")}
    """,
)

write(
    "11_goals",
    "LifeFocus - Goals",
    f"""
    <main class="page tight with-tab">
      <div class="tag">YOUR GOAL</div>
      <section class="goal-card box" style="margin-top:24px;padding:22px;">
        <div class="top-row"><div class="goal-k">あなたの目標</div><span class="edit-icon">{icon("edit")}</span></div>
        <div class="goal-v" style="font-size:28px;">英語で商談できる自分になる</div>
      </section>
      <section class="field medium" style="margin-top:16px;">
        <div class="section-label">1年後の自分</div>
        <div class="value">TOEIC 900 / 海外チームと働く</div>
      </section>
      <p class="subtitle" style="margin-top:30px;font-size:15px;">目標は、あなたを連れ戻す錨です。</p>
    </main>
    {tabbar("target")}
    """,
)

write(
    "12_stats",
    "LifeFocus - Stats",
    f"""
    <main class="page tight with-tab">
      <div class="tag">STATS · 今週</div>
      <div class="stats-big">82%</div>
      <p class="subtitle">開かずに我慢できた割合</p>
      <section class="card bar-card" style="padding:16px;margin-top:22px;">
        <div class="section-label">時間帯別</div>
        <div class="heat">
          <label>朝</label><div class="heat-track"><div class="heat-fill" style="width:54%"></div></div>
          <label>昼</label><div class="heat-track"><div class="heat-fill accent" style="width:82%"></div></div>
          <label>夜</label><div class="heat-track"><div class="heat-fill" style="width:66%"></div></div>
        </div>
        <div class="reason-list">
          <div class="reason-row"><span>暇つぶし</span><div class="reason-track"><div class="reason-fill" style="width:42%"></div></div><span>42%</span></div>
          <div class="reason-row"><span>通知</span><div class="reason-track"><div class="reason-fill" style="width:22%"></div></div><span>22%</span></div>
          <div class="reason-row"><span>習慣</span><div class="reason-track"><div class="reason-fill" style="width:20%"></div></div><span>20%</span></div>
          <div class="reason-row"><span>連絡</span><div class="reason-track"><div class="reason-fill" style="width:16%"></div></div><span>16%</span></div>
        </div>
      </section>
      <section class="line-chart">
        <svg width="350" height="96" viewBox="0 0 350 96" fill="none" aria-hidden="true">
          <path d="M9 70 C45 62 61 50 91 56 S146 80 178 44 230 26 263 36 311 62 341 26" stroke="#C7F94D" stroke-width="2" stroke-linecap="round"/>
          <path d="M9 70 C45 62 61 50 91 56 S146 80 178 44 230 26 263 36 311 62 341 26" stroke="#C7F94D" stroke-width="10" stroke-opacity=".08" stroke-linecap="round"/>
        </svg>
      </section>
    </main>
    {tabbar("stats")}
    """,
)

write(
    "13_settings",
    "LifeFocus - Settings",
    f"""
    <main class="page tight with-tab">
      <div class="tag">SETTINGS</div>
      <section class="card list-card">
        <div class="list-row"><span>介入の強さ</span><span class="chev">›</span></div>
        <div class="list-row"><span>対象アプリ</span><span class="chev">›</span></div>
        <div class="list-row"><span>ロック画面ウィジェット</span><span class="chev">›</span></div>
        <div class="list-row"><span>通知</span><span class="chev">›</span></div>
        <div class="list-row"><span>LifeFocus Pro</span><span class="mini-badge">Pro</span></div>
        <div class="list-row"><span>プライバシー</span><span class="chev">›</span></div>
        <div class="list-row"><span>利用規約</span><span class="chev">›</span></div>
      </section>
    </main>
    {tabbar("settings")}
    """,
)

write(
    "14_s01_breath",
    "LifeFocus - Breath",
    """
    <main class="page tight">
      <div class="intercept-meta">
        <span class="tag">INTERCEPTED</span>
        <span class="count">X · 今日 <b>18</b> 回目</span>
      </div>
      <section class="breath-only">
        <div class="countdown-block">
          <div class="countdown-number">3</div>
          <div class="countdown-bar"><span style="width:64%;"></span></div>
        </div>
        <div class="breath-title">ひと呼吸おきましょう</div>
        <div class="breath-sub">BREATHE · 3 SEC</div>
      </section>
    </main>
    """,
)

write(
    "15_s02_usage_summary",
    "LifeFocus - Usage Summary",
    """
    <main class="page tight">
      <div class="tag">今日のX</div>
      <div class="big-count">18回</div>
      <h1 class="title mid" style="margin-top:8px;">すでに開いています</h1>
      <section class="goal-card box" style="margin-top:34px;">
        <div class="goal-k">あなたの目標</div>
        <div class="goal-v">英語で商談できる自分になる</div>
      </section>
      <p class="subtitle" style="font-size:15px;margin-top:26px;">合計 2時間14分。英語学習に換算すると、リスニングを3本進められる時間です。</p>
      <div class="bottom-actions">
        <div class="btn primary">それでも開く理由を選ぶ</div>
        <div class="btn ghost">やめておく</div>
      </div>
    </main>
    """,
)

write(
    "16_s03_intent",
    "LifeFocus - Intent",
    """
    <main class="page tight">
      <div class="tag">INTENT</div>
      <h1 class="title" style="margin-top:24px;">何のために開きますか？</h1>
      <div class="chip-grid">
        <div class="chip">連絡の確認</div>
        <div class="chip">仕事/情報収集</div>
        <div class="chip selected">暇つぶし</div>
        <div class="chip">なんとなく</div>
      </div>
      <p class="subtitle" style="font-size:15px;margin-top:28px;">それは、今日の目標に近づきますか？</p>
      <section class="goal-card box" style="margin-top:18px;">
        <div class="goal-k">あなたの目標</div>
        <div class="goal-v" style="font-size:21px;">英語で商談できる自分になる</div>
      </section>
      <div class="bottom-actions">
        <div class="btn primary">必要な時間だけ開く</div>
        <div class="btn ghost">開かない</div>
      </div>
    </main>
    """,
)

write(
    "17_s04_time",
    "LifeFocus - Time Limit",
    """
    <main class="page tight">
      <div class="tag">TIME</div>
      <h1 class="title" style="margin-top:24px;">何分だけ開きますか？</h1>
      <div class="time-panel">
        <div class="time-value"><span>3</span><small>分</small></div>
        <div class="time-meter"><span style="width:38%;"></span></div>
      </div>
      <div class="time-pills">
        <div class="time-pill">1</div><div class="time-pill active">3</div><div class="time-pill">5</div><div class="time-pill">10</div>
      </div>
      <p class="note" style="text-align:center;margin-top:24px;">時間が来たら自動で閉じます。</p>
      <div class="bottom-actions"><div class="btn primary">3分だけ開く</div></div>
    </main>
    """,
)

write(
    "18_s05_cancel_success",
    "LifeFocus - Cancel Success",
    """
    <main class="page tight">
      <div class="center-stack" style="justify-content:flex-start;padding-top:70px;">
        <div class="success-mark">
          <svg width="64" height="42" viewBox="0 0 64 42" fill="none" aria-hidden="true">
            <path d="M9 23 24 36 55 7" stroke="currentColor" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
        </div>
        <h1 class="title">よく我慢しました。</h1>
        <p class="subtitle" style="margin-top:12px;">今日 15回目の「開かない」。</p>
        <section class="goal-card box" style="width:100%;margin-top:28px;text-align:left;">
          <div class="goal-k">あなたの目標</div>
          <div class="goal-v" style="font-size:21px;">英語で商談できる自分になる</div>
        </section>
        <div class="small-metric" style="width:100%;">今日の節約: <span class="num" style="margin-left:8px;">1時間42分</span></div>
      </div>
      <div class="bottom-actions"><div class="btn primary">閉じる</div></div>
    </main>
    """,
)

write(
    "19_s06_reintervention",
    "LifeFocus - Time Up",
    """
    <main class="page tight">
      <div class="tag">TIME UP</div>
      <h1 class="title" style="margin-top:24px;">3分が経ちました。</h1>
      <p class="subtitle">ここで止めるのがいちばん効きます。</p>
      <section class="goal-card box" style="margin-top:36px;">
        <div class="goal-k">あなたの目標</div>
        <div class="goal-v">英語で商談できる自分になる</div>
      </section>
      <div class="bottom-actions">
        <div class="btn primary">閉じる</div>
        <div class="btn ghost" style="color:var(--danger);">あと1分だけ</div>
      </div>
    </main>
    """,
)

write(
    "20_lock_widget",
    "LifeFocus - Lock Widget",
    """
    <main style="flex:1;">
      <div class="lock-clock">9:41</div>
      <section class="lock-combo-widget">
        <div class="lock-combo-main">英語で話す</div>
        <div class="lock-combo-row">
          <div class="lock-combo-sub">深く集中</div>
          <div class="lock-combo-sub">夜は見ない</div>
        </div>
      </section>
      <div class="lock-widget-note">LOCK SCREEN GOALS</div>
      <section class="lock-stat-widget">
        <div class="lock-stat-label">TODAY</div>
        <div class="lock-stat-value">0回</div>
        <div class="lock-stat-caption">開いた</div>
      </section>
      <div class="lock-icons">
        <div class="lock-icon"><svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M9 2h6v4l-2 2v12a2 2 0 0 1-4 0V8L7 6V2h2Z" fill="currentColor"/></svg></div>
        <div class="lock-icon"><svg width="27" height="24" viewBox="0 0 27 24" fill="none"><path d="M8 7 10 4h7l2 3h3a3 3 0 0 1 3 3v8a3 3 0 0 1-3 3H5a3 3 0 0 1-3-3v-8a3 3 0 0 1 3-3h3Z" fill="currentColor"/><rect x="10" y="11" width="7" height="6" rx="1.5" fill="#0A0B0D"/></svg></div>
      </div>
    </main>
    """,
    "lock",
)

write(
    "21_home_widget",
    "LifeFocus - Home Widget",
    """
    <main style="flex:1;">
      <section class="widget-small">
        <span class="lime-dot"></span>
        <div class="big">14</div>
        <div class="note" style="font-weight:700;">今日<br>開かなかった</div>
      </section>
      <section class="widget-medium">
        <div>
          <div class="section-label">YOUR GOAL</div>
          <div class="medium-goal">英語で商談できる自分になる</div>
        </div>
        <div class="mini-meter">
          <div>82%</div>
          <div class="mini-meter-track"><span style="width:82%;"></span></div>
        </div>
      </section>
      <div class="app-icons">
        <div class="dummy-app"><div class="app-tile"></div><span>MAIL</span></div>
        <div class="dummy-app"><div class="app-tile"></div><span>CAL</span></div>
        <div class="dummy-app"><div class="app-tile"></div><span>MAP</span></div>
        <div class="dummy-app"><div class="app-tile"></div><span>MEMO</span></div>
        <div class="dummy-app"><div class="app-tile"></div><span>MUSIC</span></div>
        <div class="dummy-app"><div class="app-tile"></div><span>BOOK</span></div>
        <div class="dummy-app"><div class="app-tile"></div><span>WORK</span></div>
        <div class="dummy-app"><div class="app-tile"></div><span>SET</span></div>
      </div>
    </main>
    """,
    "home-wall",
)

write(
    "22_paywall",
    "LifeFocus - Paywall",
    """
    <main class="page tight">
      <div class="tag">LIFEFOCUS PRO</div>
      <h1 class="title large" style="font-size:38px;margin-top:24px;">人生を、本気で取り戻す。</h1>
      <section class="benefits">
        <div class="benefit"><span class="tick">✓</span><span>すべてのアプリをブロック</span></div>
        <div class="benefit"><span class="tick">✓</span><span>ロック画面ウィジェット</span></div>
        <div class="benefit"><span class="tick">✓</span><span>詳細な統計とコホート</span></div>
        <div class="benefit"><span class="tick">✓</span><span>複数のロック画面目標</span></div>
      </section>
      <section class="plans">
        <div class="plan"><strong>月額</strong><span class="price">¥600</span></div>
        <div class="plan selected"><div><strong>年額</strong><div style="margin-top:5px;"><span class="mini-badge">2ヶ月分お得</span></div></div><span class="price">¥3,600</span></div>
        <div class="plan"><strong>買い切り</strong><span class="price">¥9,800</span></div>
      </section>
      <div class="bottom-actions">
        <div class="btn primary">7日間無料ではじめる</div>
        <div class="fine">いつでも解約可能 · 利用規約 · 復元</div>
      </div>
    </main>
    """,
)


render_script = """#!/usr/bin/env bash
set -euo pipefail
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
DIR="$(cd "$(dirname "$0")" && pwd)"
for f in "$DIR"/*.html; do
  name="$(basename "${f%.html}")"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \\
    --force-device-scale-factor=3 --window-size=402,874 \\
    --virtual-time-budget=4000 \\
    --screenshot="$DIR/$name.png" "file://$f" >/dev/null 2>&1
  echo "rendered $name"
done
"""

(OUT / "render.sh").write_text(render_script, encoding="utf-8")
(OUT / "render.sh").chmod(0o755)

print(f"generated {len(list(OUT.glob('*.html')))} html files in {OUT}")
