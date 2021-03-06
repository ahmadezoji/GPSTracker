import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:typed_data';

import 'package:bottom_drawer/bottom_drawer.dart';
import 'package:cargpstracker/bottomDrawer.dart';
import 'package:cargpstracker/main.dart';
import 'package:cargpstracker/models/point.dart';
import 'package:cargpstracker/theme_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
// import 'package:flutter_linear_datepicker/flutter_datepicker.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
// import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class History extends StatefulWidget {
  @override
  _HistoryState createState() => _HistoryState();
}

class _HistoryState extends State<History>
    with AutomaticKeepAliveClientMixin<History> {
  final GlobalKey<ScaffoldState> _key = GlobalKey(); // Create a key
  String serial = '';
  String label = '';
  String selectedDate = ''; //Jalali.now().toJalaliDateTime();
  late Timestamp currentTimeStamp;
  late LatLng pos = new LatLng(41.025819, 29.230415);

  // late MapboxMapController mapController;
  bool sattliteChecked = false;
  double _headerHeight = 60.0;
  double _bodyHeight = 180.0;
  BottomDrawerController _controller = BottomDrawerController();

  var currentIndex = 1;

  late double speed = 0.0;
  late double heading = 0.0;
  late double mile = 0;
  late String date = '';

  String light = 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
  String dark =
      'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png';
  String sattlite =
      'https://api.mapbox.com/v4/mapbox.satellite/{z}/{x}/{y}@2x.jpg90?access_token=${MyApp.ACCESS_TOKEN}';

  List<Point> dirArr = [];
  List<LatLng> dirLatLons = [];
  late Jalali tempPickedDate;
  late double zoomLevel = 5.0;
  late final MapController _mapController;
  var interActiveFlags = InteractiveFlag.all;
  late LatLng currentLatLng = new LatLng(35.699223, 51.337952);

  late double zoom = 11.0;
  @override
  void initState() {
    _mapController = MapController();
    super.initState();
  }

  Future<Uint8List> loadMarkerImage() async {
    var byteData = await rootBundle.load("assets/finish.png");
    return byteData.buffer.asUint8List();
  }

  void fetch(String stamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      serial = prefs.getString('serial')!;
      dirArr.clear();

      var request = http.MultipartRequest(
          'POST', Uri.parse('https://130.185.77.83:4680/history/'));
      request.fields.addAll({'serial': serial, 'timestamp': stamp});
      http.StreamedResponse response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final json = jsonDecode(responseString);
        dirLatLons.clear();
        dirArr.clear();
        for (var age in json["features"]) {
          Point p = Point.fromJson(age);
          dirLatLons.add(LatLng(p.lat, p.lon));
          dirArr.add(p);
        }
        setState(() {
          speed = dirArr[0].speed;
          mile = dirArr[0].mileage;
          heading = dirArr[0].heading;
          date = dirArr[0].dateTime;
        });
        _mapController.move(dirLatLons[0], 11);
        // _add();
      } else {
        print(response.reasonPhrase);
      }
    } catch (error) {
      print('Error add project $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeModel>(
        builder: (context, ThemeModel themeNotifier, child) {
      return Scaffold(
        key: _key,
        drawerEnableOpenDragGesture: false,
        body: buildMap(),
        extendBody: true,
        bottomNavigationBar: MyBottomDrawer(
            speed: speed, heading: heading, mile: mile, date: date),
      );
    });
  }

  String getMapThem() {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  Scaffold buildMap() {
    StreamController<void> resetController = StreamController.broadcast();
    var markers = <Marker>[
      Marker(
        width: 80.0,
        height: 80.0,
        point: currentLatLng,
        builder: (ctx) => new Container(
            child: Icon(
          Icons.motorcycle,
          size: 40,
        )),
      ),
    ];
    return Scaffold(
      endDrawer: Drawer(
          backgroundColor: Colors.white,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  //"${selectedDate.toJalaliDateTime()}".split(' ')[0],
                  "$selectedDate".split(' ')[0],
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.normal),
                ),
                SizedBox(
                  height: 20.0,
                ),
                ElevatedButton(
                  onPressed: () => _selectDate(context),
                  child: Text(
                    'Select date',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
          )),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          center: LatLng(currentLatLng.latitude, currentLatLng.longitude),
          zoom: zoomLevel,
          interactiveFlags: interActiveFlags,
        ),
        layers: [
          TileLayerOptions(
            reset: resetController.stream,
            urlTemplate: sattliteChecked ? sattlite : getMapThem(),
            subdomains: ['a', 'b', 'c'],
          ),
          PolylineLayerOptions(
            polylines: [
              Polyline(
                  points: dirLatLons, strokeWidth: 4.0, color: Colors.purple),
            ],
          ),
        ],
      ),
      floatingActionButton: _floatingBottons(),
    );
  }

  void zoomout() {
    setState(() {
      zoomLevel = zoomLevel + 1;
    });
  }

  Column _floatingBottons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          heroTag: "btn1",
          child: const Icon(Icons.zoom_in),
          onPressed: () {
            setState(() {
              zoom = zoom + 1;
            });
            _mapController.move(_mapController.center, zoom);
          },
        ),
        const SizedBox(height: 5),

        // Zoom Out
        FloatingActionButton(
          heroTag: "btn2",
          child: const Icon(Icons.zoom_out),
          onPressed: () {
            zoomout();
            setState(() {
              zoom = zoom - 1;
            });
            _mapController.move(_mapController.center, zoom);
          },
        ),
        const SizedBox(height: 5),

        // Change Style
        FloatingActionButton(
          heroTag: "btn3",
          child: const Icon(Icons.satellite),
          onPressed: () {
            // selectedStyle = selectedStyle == light ? sattlite : light;
            // fetch(currentTimeStamp.seconds.toString());
            setState(() {
              sattliteChecked = !sattliteChecked;
            });
          },
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  // void showDateDialog(BuildContext context) async {
  //   LinearDatePicker(
  //     dateChangeListener: (String selectedDate) {
  //       print(selectedDate);
  //     },
  //     showMonthName: true,
  //     isJalaali: true,
  //   );
  // }

  //change Flat to text button
  _selectDate(BuildContext context) async {
    Jalali? picked = await showPersianDatePicker(
      context: context,
      initialDate: Jalali.now(),
      firstDate: Jalali(1385, 8),
      lastDate: Jalali(1450, 9),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked.toJalaliDateTime();
      });

      Timestamp myTimeStamp =
          Timestamp.fromDate(picked.toDateTime()); //To TimeStamp
      currentTimeStamp = myTimeStamp;
      print(myTimeStamp.seconds.toString());
      fetch(myTimeStamp.seconds.toString());
    }
  }

  @override
  bool get wantKeepAlive => true;
}
