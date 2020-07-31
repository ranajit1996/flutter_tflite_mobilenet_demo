import 'dart:ffi';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite/tflite.dart';

enum Menu { Model_Settings, Class_List }
String MODEL_FILE_PATH = "assets/models/mobilenet_v1_1.0_224.tflite";
String LABELS_FILE_PATH = "assets/models/mobilenet_v1_1.0_224.txt";

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File _image;
  final ImagePicker _picker = ImagePicker();
  List<String> _classList;
  List _recognitions; // list of all predictions
  int _predictionTime; // in miliseconds

  @override
  void initState() {
    super.initState();
    _loadModel();
    _loadClassList();
  }

  void _loadModel() async {
    String res = await Tflite.loadModel(
        model: MODEL_FILE_PATH,
        labels: LABELS_FILE_PATH,
        useGpuDelegate: true);
  }

  void _loadImageFromGallery() async {
    PickedFile image = await _picker.getImage(
        source: ImageSource.gallery);
    setState(() {
      _image = image != null ? File(image.path) : null;
    });
  }

  void _loadImageFromCamera() async {
    PickedFile image = await _picker.getImage(
        source: ImageSource.camera, preferredCameraDevice: CameraDevice.rear);
    setState(() {
      _image = image != null ? File(image.path) : null;
    });
  }

  void _loadClassList() async{
    if(_classList != null) return;
    String classListString = await rootBundle.loadString(LABELS_FILE_PATH);
    List<String> classList = List<String>();
    classListString.split('\n').forEach((String className) {
      classList.add(className);
    });
    setState(() {
      _classList = classList;
    });
  }

  Future _predictImage() async {
    if (_image == null) return;
    int startTime = DateTime.now().millisecondsSinceEpoch;
    _recognitions = await Tflite.runModelOnImage(
      path: _image.path,
      imageMean: 127.5,
      imageStd: 127.5,
      numResults: 10,
      threshold: 0.2,
      asynch: true,
    );
    int endTime = DateTime.now().millisecondsSinceEpoch;
    _predictionTime = endTime - startTime;
  }

  List<Widget> _getPredictionsText() {
    List<Widget> listOfWidgets = List<Widget>();
    for (final Map<dynamic, dynamic> prediction in _recognitions) {
      List<Widget> cardChildren = List<Widget>();
      prediction.forEach((key, value) {
        cardChildren.add(Text(
          "${key.toString()}:  ${value.toString()}",
          textAlign: TextAlign.start,
        ));
      });
      listOfWidgets.add(Padding(
        padding: EdgeInsets.all(10),
        child: Card(
          color: Colors.tealAccent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cardChildren,
          ),
        ),
      ));
    }
    return listOfWidgets;
  }

  void _predictionModalBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      isDismissible: true,
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              child: ListView(
                controller: scrollController,
                children: <Widget>[
                  Text(
                    "Prediction Results",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Prediction time: $_predictionTime ms",
                    textAlign: TextAlign.center,
                  ),
                  _recognitions.isNotEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _getPredictionsText())
                      : Container(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            "No objects detected",
                            textAlign: TextAlign.center,
                          ),
                        )
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _classListModalBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      isDismissible: true,
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              child: ListView.builder(
                controller: scrollController,
//                padding: EdgeInsets.all(10),
                itemCount: _classList.length,
                itemBuilder: (BuildContext context, int index){
                  return ListTile(
                    title: Text("Item $index : ${_classList[index]}"),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Mobilenet Tflite Demo"),
        actions: <Widget>[
          PopupMenuButton<Menu>(
            onSelected: (Menu selection) {
              switch (selection) {
                case Menu.Class_List:
                  if(_classList == null) break;
                  _classListModalBottomSheet(context);
                  break;
              }
            },
            icon: Icon(Icons.settings),
            offset: Offset(0, 40),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<Menu>>[
              const PopupMenuItem(
                height: 25,
                value: Menu.Class_List,
                child: Text("Class List"),
              ),
            ],
          )
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _image != null
              ? Image.file(
                  _image,
                  width: MediaQuery.of(context).size.width - 50,
                  height: MediaQuery.of(context).size.height / 1.5,
                )
              : Container(
                  child: Center(child: Text("No Image Selected")),
                  width: MediaQuery.of(context).size.width - 50,
                  height: MediaQuery.of(context).size.height / 1.5,
                ),
          SizedBox(width: double.infinity, height: 50),
          RaisedButton(
            onPressed: () async {
              if (_image == null) return;
              await _predictImage();
              _predictionModalBottomSheet(context);
            },
            child: Text("Predict"),
            color: Colors.purple,
            textColor: Colors.white,
          )
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.horizontal(left: Radius.circular(30))
            ),
            onPressed: _loadImageFromGallery,
            child: Icon(Icons.image),
          ),
          Container(
            height: 0.1,
            width: 1.5,
          ),
          FloatingActionButton(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.horizontal(right: Radius.circular(30)),
            ),
            onPressed: _loadImageFromCamera,
            child: Icon(Icons.camera),
          ),
        ],
      ),
    );
  }
}
