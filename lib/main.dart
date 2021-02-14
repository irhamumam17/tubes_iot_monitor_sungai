import 'dart:async';
import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monitor Sungai APP',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
        // This makes the visual density adapt to the platform that you run
        // the app on. For desktop platforms, the controls will be smaller and
        // closer together (more dense) than on mobile platforms.
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: AppBarTheme(
          elevation: 0,
        )
      ),
      home: MyHomePage(title: 'Monitor Sungai'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final client = MqttServerClient('iotpintar.net', '');
  final topic = 'polines/ik3a/kel04/suhu'; // Not a wildcard topic
  String suhu = "0";
  bool _aman = false;
  bool _waspada = false;
  bool _bahaya = false;
  bool _connecting = false;
  bool _not_connected = false;

  Future<int> connect() async {
  /// A websocket URL must start with ws:// or wss:// or Dart will throw an exception, consult your websocket MQTT broker
  /// for details.
  /// To use websockets add the following lines -:
  /// client.useWebSocket = true;
  /// client.port = 80;  ( or whatever your WS port is)
  /// There is also an alternate websocket implementation for specialist use, see useAlternateWebSocketImplementation
  /// Note do not set the secure flag if you are using wss, the secure flags is for TCP sockets only.
  /// You can also supply your own websocket protocol list or disable this feature using the websocketProtocols
  /// setter, read the API docs for further details here, the vast majority of brokers will support the client default
  /// list so in most cases you can ignore this.

  /// Set logging on if needed, defaults to off
  client.logging(on: false);

  /// If you intend to use a keep alive value in your connect message that is not the default(60s)
  /// you must set it here
  client.keepAlivePeriod = 20;

  /// Add the unsolicited disconnection callback
  client.onDisconnected = onDisconnected;

  /// Add the successful connection callback
  client.onConnected = onConnected;

  /// Add a subscribed callback, there is also an unsubscribed callback if you need it.
  /// You can add these before connection or change them dynamically after connection if
  /// you wish. There is also an onSubscribeFail callback for failed subscriptions, these
  /// can fail either because you have tried to subscribe to an invalid topic or the broker
  /// rejects the subscribe request.
  client.onSubscribed = onSubscribed;

  /// Set a ping received callback if needed, called whenever a ping response(pong) is received
  /// from the broker.
  client.pongCallback = pong;

  /// Create a connection message to use or use the default one. The default one sets the
  /// client identifier, any supplied username/password, the default keepalive interval(60s)
  /// and clean session, an example of a specific one below.
  final connMess = MqttConnectMessage()
      .withClientIdentifier('Mqtt_MyClientUniqueId')
      .keepAliveFor(20) // Must agree with the keep alive set above or not set
      // .withWillTopic('willtopic') // If you set this you must set a will message
      // .withWillMessage('My Will message')
      .startClean() // Non persistent session for testing
      .withWillQos(MqttQos.atLeastOnce);
  print('EXAMPLE::Mosquitto client connecting....');
  client.connectionMessage = connMess;

  /// Connect the client, any errors here are communicated by raising of the appropriate exception. Note
  /// in some circumstances the broker will just disconnect us, see the spec about this, we however will
  /// never send malformed messages.
  try {
    await client.connect();
    _connecting = true;
  } on NoConnectionException catch (e) {
    // Raised by the client when connection fails.
    print('EXAMPLE::client exception - $e');
    client.disconnect();
  } on SocketException catch (e) {
    // Raised by the socket layer
    print('EXAMPLE::socket exception - $e');
    client.disconnect();
  }

  /// Check we are connected
  if (client.connectionStatus.state == MqttConnectionState.connected) {
    print('EXAMPLE::Mosquitto client connected');
    _connecting = false;
    _not_connected = false;
  } else {
    /// Use status here rather than state if you also want the broker return code.
    print(
        'EXAMPLE::ERROR Mosquitto client connection failed - disconnecting, status is ${client.connectionStatus}');
    _connecting = false;
    _not_connected = true;
    client.disconnect();
    exit(-1);
  }

  /// Ok, lets try a subscription
  print('EXAMPLE::Subscribing to the polines/ik3a/kel04/suhu topic');
  client.subscribe(topic, MqttQos.atMostOnce);

  /// The client has a change notifier object(see the Observable class) which we then listen to to get
  /// notifications of published updates to each subscribed topic.
  client.updates.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage recMess = c[0].payload;
      final pt =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      /// The above may seem a little convoluted for users only interested in the
      /// payload, some users however may be interested in the received publish message,
      /// lets not constrain ourselves yet until the package has been in the wild
      /// for a while.
      /// The payload is a byte buffer, this will be specific to the topic
      print(
          'EXAMPLE::Change notification:: topic is <${c[0].topic}>, payload is <-- $pt -->');
      print('');
      setState(() {
        _aman = false;
        _waspada = false;
        _bahaya = false;
        var singleline = pt.replaceAll("\n", " ");
        suhu = singleline;
        var dSuhu = double.parse(pt);
        if (dSuhu<=25){
          _aman = true;
        }else if(dSuhu>25 && dSuhu<=32){
          _waspada = true;
        }else{
          _bahaya = true;
        }
      });
    });

  /// If needed you can listen for published messages that have completed the publishing
  /// handshake which is Qos dependant. Any message received on this stream has completed its
  /// publishing handshake with the broker.
  client.published.listen((MqttPublishMessage message) {
    print(
        'EXAMPLE::Published notification:: topic is ${message.variableHeader.topicName}, with Qos ${message.header.qos}');
  });

  /// Lets publish to our topic
  /// Use the payload builder rather than a raw buffer
  /// Our known topic to publish to
  const suhuTopic = 'polines/ik3a/kel04/suhu';
  const statusTopic = 'polines/ik3a/kel04/status';
  final suhuBuilder = MqttClientPayloadBuilder();
  final statusBuilder = MqttClientPayloadBuilder();
  suhuBuilder.addString('20');
  suhuBuilder.addString('Aman');

  /// Subscribe to it
  print('EXAMPLE::Subscribing to the polines/ik3a/kel04/suhu topic');
  client.subscribe(suhuTopic, MqttQos.exactlyOnce);

  /// Publish it
  // print('EXAMPLE::Publishing our topic');
  // client.publishMessage(suhuTopic, MqttQos.exactlyOnce, suhuBuilder.payload);

  /// Ok, we will now sleep a while, in this gap you will see ping request/response
  /// messages being exchanged by the keep alive mechanism.
  print('EXAMPLE::Sleeping....');
  await MqttUtilities.asyncSleep(120);

  /// Finally, unsubscribe and exit gracefully
  print('EXAMPLE::Unsubscribing');
  client.unsubscribe(topic);

  /// Wait for the unsubscribe message from the broker if you wish.
  await MqttUtilities.asyncSleep(2);
  print('EXAMPLE::Disconnecting');
  client.disconnect();
  return 0;
}
  /// The subscribed callback
  void onSubscribed(String topic) {
    print('EXAMPLE::Subscription confirmed for topic $topic');
  }

  /// The unsolicited disconnect callback
  void onDisconnected() {
    print('EXAMPLE::OnDisconnected client callback - Client disconnection');
    if (client.connectionStatus.disconnectionOrigin ==
        MqttDisconnectionOrigin.solicited) {
      print('EXAMPLE::OnDisconnected callback is solicited, this is correct');
    }
    exit(-1);
  }

  /// The successful connect callback
  void onConnected() {
    print(
        'EXAMPLE::OnConnected client callback - Client connection was sucessful');
  }

  /// Pong callback
  void pong() {
    print('EXAMPLE::Ping response client callback invoked');
  }
  @override
  void initState() {
    super.initState();
    connect();
  }
  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              margin: const EdgeInsets.fromLTRB(0, 0, 0, 10),
              child: 
                Image(image: AssetImage("assets/images/logo.png")),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(0, 0, 0, 20),
              child:
              Text(
                "Result",
                style: new TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 20.0,
                  color: Colors.black,
                ),
              )
            ),
            Text("Current Temperature :"),
            Container(
              margin: const EdgeInsets.fromLTRB(0, 0, 0, 20),
              child:
              Text(
                "$suhu Celcius",
                style: new TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 20.0,
                  color: Colors.grey,
                ),
              )
            ),
            Visibility(visible: _connecting,child: 
              ButtonTheme(
                  height: 50,
                  child: 
                  FlatButton.icon(
                    onPressed: null,
                    icon: Icon(
                      Icons.perm_scan_wifi,
                      color: Colors.grey,
                      size: 50
                    ),
                    label: Text(
                      "Menghubungkan...",
                      style: new TextStyle(
                        fontSize: 20.0,
                        color: Colors.grey,
                      ),
                    )
                  )
              )
            ),
            Visibility(visible: _not_connected,child: 
              ButtonTheme(
                  height: 50,
                  child: 
                  FlatButton.icon(
                    onPressed: null,
                    icon: Icon(
                      Icons.signal_wifi_off,
                      color: Colors.redAccent,
                      size: 50
                    ),
                    label: Text(
                      "Perangkat Tidak Tersambung",
                      style: new TextStyle(
                        fontSize: 20.0,
                        color: Colors.red,
                      ),
                    )
                  )
              )
            ),
            Visibility(visible: _aman,child: 
              ButtonTheme(
                  height: 50,
                  child: 
                  FlatButton.icon(
                    onPressed: null,
                    icon: Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 50
                    ),
                    label: Text(
                      "Aman",
                      style: new TextStyle(
                        fontSize: 20.0,
                        color: Colors.green,
                      ),
                    )
                  )
              )
            ),
            Visibility(visible: _waspada,child: 
              ButtonTheme(
                height: 50,
                child: 
                FlatButton.icon(
                  onPressed: null,
                  icon: Icon(
                    Icons.warning,
                    color: Colors.yellow,
                    size: 50
                  ),
                  label: Text(
                    "Waspada",
                    style: new TextStyle(
                      fontSize: 20.0,
                      color: Colors.yellow,
                    ),
                  )
                )
              )
            ),
            Visibility(visible: _bahaya,child: 
              ButtonTheme(
                height: 50,
                child: 
                FlatButton.icon(
                  onPressed: null,
                  icon: Icon(
                    Icons.cancel,
                    color: Colors.red,
                    size: 50
                  ),
                  label: Text(
                    "Bahaya",
                    style: new TextStyle(
                      fontSize: 20.0,
                      color: Colors.red,
                    ),
                  )
                )
              )
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: ()=>{
          client.updates.listen((List<MqttReceivedMessage<MqttMessage>> c) {
            final MqttPublishMessage recMess = c[0].payload;
            final pt =
                MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
                setState(() {
                  _aman = false;
                  _waspada = false;
                  _bahaya = false;
                  _connecting = false;
                  _not_connected = false;
                  suhu = pt;
                  var dSuhu = double.parse(pt);
                  if (dSuhu<=25){
                    _aman = true;
                  }else if(dSuhu>25 && dSuhu<=32){
                    _waspada = true;
                  }else{
                    _bahaya = true;
                  }
                });
          })
        },
        tooltip: 'Refresh',
        child: Icon(Icons.autorenew),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

