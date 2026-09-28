import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: AuthGate()));

class Candle { double o,h,l,c; Candle(this.o,this.h,this.l,this.c); }
const String adminEmail = "maroa0472@gmail.com";

class AuthGate extends StatefulWidget { const AuthGate({super.key}); @override State<AuthGate> createState()=> _AuthGateState(); }
class _AuthGateState extends State<AuthGate>{
  bool isUnlocked = false;
  String userEmail = "";
  @override Widget build(BuildContext context){
    if(!isUnlocked){
      return Scaffold(backgroundColor: const Color(0xFF080808), body: ProfileAuthPage(onSuccess: (e){ setState((){ isUnlocked=true; userEmail=e; }); }));
    }
    return TimoApp(userEmail: userEmail, onLogout: (){ setState(()=> isUnlocked=false); });
  }
}

class TimoApp extends StatefulWidget {
  final String userEmail; final VoidCallback onLogout;
  const TimoApp({super.key, required this.userEmail, required this.onLogout});
  @override State<TimoApp> createState()=> _TimoState();
}

class _TimoState extends State<TimoApp>{
  int navIndex=0; List<Candle> candles=[]; double livePrice=4285.30; double openP=0;
  String selectedTf='1D'; String currentSymbol='PAXGUSDT'; String currentName='GOLD • XAU/USD';
  String status='LIVE'; Timer? liveTimer; final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  List<Map<String,dynamic>> pairs=[
    {'name':'GOLD','display':'XAU/USD','symbol':'PAXGUSDT'},
    {'name':'EUR/USD','display':'EUR/USD','symbol':'EURUSDT'},
    {'name':'GBP/USD','display':'GBP/USD','symbol':'GBPUSDT'},
    {'name':'BTC/USD','display':'BTC/USD','symbol':'BTCUSDT'},
    {'name':'ETH/USD','display':'ETH/USD','symbol':'ETHUSDT'},
    {'name':'USD/EGP','display':'USD/EGP','symbol':'PAXGUSDT'},
  ];

  List<Candle> generateZigzag(double startPrice, int count, double volatility){
    Random rnd = Random(); List<Candle> list = []; double price = startPrice; double trend = 1; int trendCounter = 0;
    for(int i=0;i<count;i++){
      trendCounter++; if(trendCounter > 4 + rnd.nextInt(6)){ trend = -trend; trendCounter = 0; }
      double change = (rnd.nextDouble() * volatility * 0.7 + volatility*0.3) * trend;
      change += (rnd.nextDouble() - 0.5) * (volatility * 0.5);
      double o = price; double c = o + change;
      double h = max(o,c) + rnd.nextDouble() * volatility * 0.6;
      double l = min(o,c) - rnd.nextDouble() * volatility * 0.6;
      list.add(Candle(o,h,l,c)); price = c;
    }
    return list;
  }

  Future<void> loadData(String tf) async {
    String interval='15m'; double vol=3.5;
    if(tf=='1m'){ interval='1m'; vol=0.8; } if(tf=='5m'){ interval='5m'; vol=1.2; }
    if(tf=='10m'){ interval='15m'; vol=1.8; } if(tf=='15m'){ interval='15m'; vol=2.2; }
    if(tf=='30m'){ interval='30m'; vol=2.8; } if(tf=='1H'){ interval='1h'; vol=4.5; }
    if(tf=='1D'){ interval='1d'; vol=12; } if(tf=='1W'){ interval='1w'; vol=35; }
    if(tf=='1M'){ interval='1M'; vol=70; } if(tf=='1Y'){ interval='1M'; vol=90; }
    try{
      var r=await http.get(Uri.parse('https://data-api.binance.vision/api/v3/klines?symbol=$currentSymbol&interval=$interval&limit=70')).timeout(const Duration(seconds:6));
      if(r.statusCode==200){
        var d=jsonDecode(r.body); List<Candle> tmp=[];
        for(var e in d){ tmp.add(Candle(double.parse(e[1]), double.parse(e[2]), double.parse(e[3]), double.parse(e[4]))); }
        setState((){ candles=tmp; livePrice=tmp.last.c; openP=tmp.first.o; selectedTf=tf; status='LIVE $tf'; });
        return;
      }
    }catch(_){}
    var zz = generateZigzag(livePrice, 70, vol);
    setState((){ candles=zz; livePrice=zz.last.c; openP=zz.first.o; selectedTf=tf; status='DEMO $tf ZIGZAG'; });
  }

  void startLiveZigzag(){
    liveTimer?.cancel();
    liveTimer=Timer.periodic(const Duration(milliseconds:650), (_){
      if(candles.isEmpty) return; Random rnd=Random();
      double lastTrend = candles.last.c >= candles.last.o? 1 : -1;
      double newTrend = rnd.nextDouble() < 0.7? lastTrend : -lastTrend;
      double change = (rnd.nextDouble()*1.2 + 0.2) * newTrend;
      setState((){
        livePrice+=change; var last=candles.last;
        double newH = max(last.h, livePrice); double newL = min(last.l, livePrice);
        candles[candles.length-1]=Candle(last.o, newH, newL, livePrice);
        if(rnd.nextDouble() < 0.12){
          double o = livePrice; double c = o + (rnd.nextDouble()-0.5)*1.5;
          double h = max(o,c)+rnd.nextDouble(); double l = min(o,c)-rnd.nextDouble();
          candles.add(Candle(o,h,l,c)); if(candles.length>70) candles.removeAt(0);
        }
      });
    });
  }

  void selectPair(Map<String,dynamic> p){
    setState((){
      currentSymbol=['PAXGUSDT','BTCUSDT','ETHUSDT','EURUSDT','GBPUSDT'].contains(p['symbol'])? p['symbol'] : 'PAXGUSDT';
      currentName='${p['name']} • ${p['display']}'; navIndex=0; candles=[];
    });
    loadData(selectedTf); if(scaffoldKey.currentState?.isDrawerOpen??false) Navigator.pop(context);
  }

  @override void initState(){ super.initState(); loadData('1D'); startLiveZigzag(); }
  @override void dispose(){ liveTimer?.cancel(); super.dispose(); }

  @override Widget build(BuildContext context){
    double maxH=candles.isEmpty?1:candles.map((e)=>e.h).reduce(max);
    double minL=candles.isEmpty?0:candles.map((e)=>e.l).reduce(min);
    return Scaffold(
      key: scaffoldKey, backgroundColor: const Color(0xFF080808),
      drawer: Drawer(backgroundColor: const Color(0xFF121212), child: Column(children: [
        Container(height:160, width: double.infinity, color: const Color(0xFFFFD700).withOpacity(0.1), padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
            Image.asset('assets/logo.png', width: 55, height: 55, errorBuilder: (c,e,s)=> const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 45)),
            const SizedBox(height:10),
            Text(widget.userEmail, style: const TextStyle(color: Color(0xFFFFD700), fontSize:11, fontWeight:FontWeight.bold)),
            const SizedBox(height:2),
            Text(widget.userEmail.toLowerCase()==adminEmail? "ADMIN - TIMO GOLD": "PRO MEMBER", style: const TextStyle(color: Colors.white54, fontSize:11)),
          ])),
        ListTile(leading: const Icon(Icons.show_chart, color: Color(0xFFFFD700)), title: const Text("الشارت الزجزاج", style: TextStyle(color: Colors.white)), onTap: (){ setState(()=> navIndex=0); Navigator.pop(context); }),
        ListTile(leading: const Icon(Icons.list, color: Color(0xFFFFD700)), title: const Text("الازواج", style: TextStyle(color: Colors.white)), onTap: (){ setState(()=> navIndex=1); Navigator.pop(context); }),
        const Divider(color: Colors.white10),
        ListTile(leading: const Icon(Icons.logout, color: Colors.redAccent), title: const Text("خروج", style: TextStyle(color: Colors.redAccent)), onTap: widget.onLogout),
      ])),
      body: SafeArea(child: Column(children: [
        Container(height:56, color: const Color(0xFF121212), padding: const EdgeInsets.symmetric(horizontal:12),
          child: Row(children: [
            IconButton(onPressed: ()=> scaffoldKey.currentState?.openDrawer(), icon: const Icon(Icons.menu, color: Color(0xFFFFD700))),
            Image.asset('assets/logo.png', width: 32, height: 32, errorBuilder: (c,e,s)=> const Icon(Icons.monetization_on, color: Color(0xFFFFD700))),
            const SizedBox(width:8),
            Expanded(child: Text(currentName, style: const TextStyle(color: Color(0xFFFFD700), fontWeight:FontWeight.bold, fontSize:12))),
            Container(padding: const EdgeInsets.symmetric(horizontal:8,vertical:4), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)), child: Text(status, style: const TextStyle(color: Colors.white60, fontSize:9))),
          ])),
        Expanded(child: navIndex==0? zigzagChart(maxH,minL): marketsPage()),
      ])),
      bottomNavigationBar: BottomNavigationBar(backgroundColor: const Color(0xFF0F0F0F), selectedItemColor: const Color(0xFFFFD700), unselectedItemColor: Colors.white38, currentIndex: navIndex, onTap: (i)=> setState(()=> navIndex=i), items: const [BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Chart'), BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Markets')]),
    );
  }

  Widget zigzagChart(double maxH,double minL){
    if(candles.isEmpty) return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
    return Column(children: [
      const SizedBox(height:12),
      Text('\$${livePrice.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFFFD700), fontSize:38, fontWeight:FontWeight.w900)),
      Text(livePrice>=openP? '+${(livePrice-openP).toStringAsFixed(2)} صاعد ▲' : '${(livePrice-openP).toStringAsFixed(2)} هابط ▼', style: TextStyle(color: livePrice>=openP? Colors.greenAccent: Colors.redAccent, fontSize:12, fontWeight:FontWeight.bold)),
      const SizedBox(height:12),
      SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal:8),
        child: Row(children: ['1m','5m','10m','15m','30m','1H','1D','1W','1M','1Y'].map((t){ bool sel=t==selectedTf; return Padding(padding: const EdgeInsets.only(right:6), child: GestureDetector(onTap: ()=> loadData(t), child: Container(padding: const EdgeInsets.symmetric(horizontal:14,vertical:8), decoration: BoxDecoration(color: sel? const Color(0xFFFFD700): Colors.white10, borderRadius: BorderRadius.circular(20)), child: Text(t, style: TextStyle(color: sel? Colors.black: Colors.white70, fontWeight:FontWeight.bold, fontSize:12)))));}).toList())),
      const SizedBox(height:10),
      Expanded(child: Container(color: const Color(0xFF0F0F0F), padding: const EdgeInsets.fromLTRB(8,12,8,8), child: CustomPaint(size: Size.infinite, painter: ZigzagPainter(candles: candles, maxH: maxH, minL: minL)))),
      Container(height:36, color: const Color(0xFF121212), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        Text('OPEN ${openP.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white38, fontSize:10)),
        Text('HIGH ${maxH.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontSize:10)),
        Text('LOW ${minL.toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontSize:10)),
      ])),
    ]);
  }
  Widget marketsPage(){
    return Column(children: [
      Container(height:40, color: const Color(0xFF121212), padding: const EdgeInsets.all(10), child: const Text('دوس على الزوج - هيفتح زجزاج في الشارت', style: TextStyle(color: Color(0xFFFFD700), fontSize:11))),
      Expanded(child: ListView.separated(itemCount: pairs.length, separatorBuilder: (_,__)=> const Divider(color: Colors.white10, height:1), itemBuilder: (_,i){ var p=pairs[i]; return ListTile(leading: Image.asset('assets/logo.png', width: 28, height: 28, errorBuilder: (c,e,s)=> const Icon(Icons.monetization_on, color: Color(0xFFFFD700))), title: Text(p['display'], style: const TextStyle(color: Colors.white, fontWeight:FontWeight.bold)), trailing: const Icon(Icons.chevron_right, color: Colors.white24), onTap: ()=> selectPair(p)); })),
    ]);
  }
}

class ZigzagPainter extends CustomPainter{
  final List<Candle> candles; final double maxH, minL;
  ZigzagPainter({required this.candles, required this.maxH, required this.minL});
  @override void paint(Canvas canvas, Size size){
    double range = maxH - minL; if(range==0) range=1; double candleW = size.width / candles.length;
    Paint zigzagLine = Paint()..color = const Color(0xFFFFD700).withOpacity(0.6)..style = PaintingStyle.stroke..strokeWidth = 1.2;
    Path path = Path();
    for(int i=0;i<candles.length;i++){
      double x = i * candleW + candleW/2; double y = size.height - ((candles[i].c - minL)/range * size.height);
      if(i==0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, zigzagLine);
    for(int i=0;i<candles.length;i++){
      var c = candles[i]; double x = i * candleW + candleW/2;
      double oY = size.height - ((c.o - minL)/range * size.height);
      double cY = size.height - ((c.c - minL)/range * size.height);
      double hY = size.height - ((c.h - minL)/range * size.height);
      double lY = size.height - ((c.l - minL)/range * size.height);
      bool bull = c.c >= c.o;
      Paint wickPaint = Paint()..color = bull? Colors.greenAccent: Colors.redAccent..strokeWidth = 1;
      Paint bodyPaint = Paint()..color = bull? const Color(0xFF00E676): const Color(0xFFFF3D42);
      canvas.drawLine(Offset(x, hY), Offset(x, lY), wickPaint);
      double bodyTop = min(oY,cY); double bodyH = max(2, (oY-cY).abs());
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - candleW*0.35, bodyTop, candleW*0.7, bodyH), const Radius.circular(2)), bodyPaint);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate)=> true;
}

class ProfileAuthPage extends StatefulWidget {
  final Function(String) onSuccess; const ProfileAuthPage({super.key, required this.onSuccess});
  @override State<ProfileAuthPage> createState()=> _ProfileAuthPageState();
}
class _ProfileAuthPageState extends State<ProfileAuthPage> {
  final emailCtrl = TextEditingController(); final codeCtrl = TextEditingController();
  String selectedPay = ""; bool isPaid = false;
  final Map<String,String> payNumbers = {'vodafone': '01019298377','orange': '01234567890','we': '01534567890','etisalat': '01134567890','instapay': 'timo@instapay',};
  final String whatsappNumber = "01021267857";
  final List<Map<String,String>> payMethods = [{'name':'فودافون كاش','id':'vodafone'},{'name':'اورانج كاش','id':'orange'},{'name':'وي كاش','id':'we'},{'name':'اتصالات كاش','id':'etisalat'},{'name':'انستا باي','id':'instapay'},];
  final String masterCode = "TIMO2026";
  void submitPayment(){
    String email = emailCtrl.text.trim().toLowerCase();
    if(email == adminEmail){ widget.onSuccess(email); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أهلا يا أدمن Timo 😎'))); return; }
    if(!email.contains('@') || selectedPay.isEmpty){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حط الجيميل واختار وسيلة الدفع'))); return; }
    setState(()=> isPaid=true);
  }
  void activate(){ if(codeCtrl.text.trim().toUpperCase() == masterCode){ widget.onSuccess(emailCtrl.text.trim()); }else{ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('كود غلط - ابعت على $whatsappNumber'))); } }
  @override Widget build(BuildContext context){
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
      const SizedBox(height:40),
      Center(child: Column(children: [
        Image.asset('assets/logo.png', width: 90, height: 90, errorBuilder: (c,e,s)=> const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 70)),
        const SizedBox(height:12),
        const Text("TIMO GOLD PRO", style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize:22)),
        const Text("شارت زجزاج حقيقي", style: TextStyle(color: Colors.white38, fontSize:11)),
      ])),
      const SizedBox(height:30),
      if(!isPaid)...[
        TextField(controller: emailCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Gmail", hintText: "maroa0472@gmail.com يفتح مباشر", hintStyle: const TextStyle(color: Colors.white24, fontSize:10), prefixIcon: const Icon(Icons.email, color: Color(0xFFFFD700)), filled: true, fillColor: const Color(0xFF1A1A1A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height:18),
        const Align(alignment: Alignment.centerRight, child: Text("اختار وسيلة الدفع:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        const SizedBox(height:10),
        Wrap(spacing:8, runSpacing:8, children: payMethods.map((m){ bool sel=selectedPay==m['id']; return GestureDetector(onTap: ()=> setState(()=> selectedPay=m['id']!), child: Container(padding: const EdgeInsets.symmetric(horizontal:14,vertical:10), decoration: BoxDecoration(color: sel? const Color(0xFFFFD700): const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: sel? const Color(0xFFFFD700): Colors.white12)), child: Text(m['name']!, style: TextStyle(color: sel? Colors.black: Colors.white, fontSize:11, fontWeight:FontWeight.bold))));}).toList()),
        const SizedBox(height:24),
        SizedBox(width: double.infinity, height:52, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: submitPayment, child: const Text("دخول", style: TextStyle(color: Colors.black, fontWeight:FontWeight.bold)))),
      ] else...[
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.6))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("حول على ${payMethods.firstWhere((e)=>e['id']==selectedPay)['name']}", style: const TextStyle(color: Color(0xFFFFD700), fontWeight:FontWeight.bold)),
            const SizedBox(height:10),
            Container(width: double.infinity, padding: const EdgeInsets.all(12), color: Colors.black, child: Text(payNumbers[selectedPay]!, style: const TextStyle(color: Colors.white, fontSize:22, fontWeight:FontWeight.w900))),
            const SizedBox(height:10),
            Row(children: [const Icon(Icons.chat_bubble, color: Colors.greenAccent, size:18), const SizedBox(width:6), Text("واتساب: $whatsappNumber", style: const TextStyle(color: Colors.greenAccent, fontWeight:FontWeight.bold))]),
          ])),
        const SizedBox(height:18),
        TextField(controller: codeCtrl, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, letterSpacing:4), decoration: InputDecoration(labelText: "كود التفعيل", prefixIcon: const Icon(Icons.vpn_key, color: Color(0xFFFFD700)), filled: true, fillColor: const Color(0xFF1A1A1A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height:12),
        SizedBox(width: double.infinity, height:52, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: activate, child: const Text("تفعيل 🔓", style: TextStyle(color: Colors.black, fontWeight:FontWeight.bold)))),
      ]
    ]));
  }
}