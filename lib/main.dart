import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'dart:typed_data'; // Import for Uint8List

void main() {
  runApp(CarScannerApp());
}

class CarScannerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Scanner App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => HomePage(),
        '/number_plate_detector': (context) => NumberPlateDetector(),
        '/scan_history': (context) => ScanHistoryPage(),
      },
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Car Scanner Home'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.pushNamed(context, '/number_plate_detector');
          },
          child: Text('Start Scanning'),
        ),
      ),
    );
  }
}

class NumberPlateDetector extends StatefulWidget {
  @override
  _NumberPlateDetectorState createState() => _NumberPlateDetectorState();
}

class _NumberPlateDetectorState extends State<NumberPlateDetector> {
  late CameraController _cameraController;
  late TextDetector _textDetector;
  List<CameraDescription> _cameras = [];
  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _textDetector = GoogleMlKit.vision.textDetector();
  }

  void _initializeCamera() async {
    _cameras = await availableCameras();
    _cameraController = CameraController(_cameras[0], ResolutionPreset.high);
    await _cameraController.initialize();
    if (!mounted) return;
    setState(() {});
  }

  void _startDetecting() {
    _cameraController.startImageStream((CameraImage image) {
      if (_isDetecting) {
        _detectText(image);
      }
    });
  }

  void _detectText(CameraImage image) async {
    final inputImage = InputImage.fromBytes(
      bytes: concatenatePlanes(image.planes),
      inputImageData: InputImageData(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        imageRotation: InputImageRotation.Rotation_90deg,
        inputImageFormat: InputImageFormat.NV21,
        planeData: image.planes.map(
          (Plane plane) {
            return InputImagePlaneMetadata(
              bytesPerRow: plane.bytesPerRow,
              height: plane.height,
              width: plane.width,
            );
          },
        ).toList(),
      ),
    );

    final RecognisedText recognisedText =
        await _textDetector.processImage(inputImage);

    for (TextBlock block in recognisedText.blocks) {
      for (TextLine line in block.lines) {
        print('Detected text: ${line.text}');
      }
    }
  }

  Uint8List concatenatePlanes(List<Plane> planes) {
    final List<Uint8List> planeBytes =
        planes.map((Plane plane) => plane.bytes).toList();
    return Uint8List.fromList(planeBytes.expand((list) => list).toList());
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _textDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraController.value.isInitialized) {
      return Container();
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Number Plate Detector'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: <Widget>[
                CameraPreview(_cameraController),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _isDetecting = !_isDetecting;
                });
                if (_isDetecting) {
                  _startDetecting();
                } else {
                  _cameraController.stopImageStream();
                }
              },
              child: Text(_isDetecting ? 'Stop Detection' : 'Start Detection'),
            ),
          ),
        ],
      ),
    );
  }
}

class ScanHistoryPage extends StatefulWidget {
  @override
  _ScanHistoryPageState createState() => _ScanHistoryPageState();
}

class _ScanHistoryPageState extends State<ScanHistoryPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  List<String> scanHistory = [];

  @override
  void initState() {
    super.initState();
    _getScanHistory();
  }

  Future<void> _getScanHistory() async {
    User? user = _auth.currentUser;
    if (user != null) {
      QuerySnapshot historySnapshot = await _firestore
          .collection('scan_history')
          .doc(user.uid)
          .collection('scans')
          .get();

      if (historySnapshot.docs.isNotEmpty) {
        setState(() {
          scanHistory = historySnapshot.docs
              .map((doc) => doc['scan_data'] as String)
              .toList();
        });
      } else {
        print('No scan history found.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan History'),
      ),
      body: ListView.builder(
        itemCount: scanHistory.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(scanHistory[index]),
          );
        },
      ),
    );
  }
}
