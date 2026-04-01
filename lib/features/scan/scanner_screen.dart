import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:alt/utils/camera_utils.dart';
import '../../app/providers.dart';
import 'package:alt/core/domain/models/user_profile.dart';
import 'scan_controller.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInit = false;

  // Scanners
  final BarcodeScanner _barcodeScanner = BarcodeScanner();

  bool _isProcessing = false;
  bool _canScan = false; // Default to false (Manual Trigger)
  bool _isPhysicalDevice = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkDeviceType();
  }

  Future<void> _checkDeviceType() async {
    final deviceInfo = DeviceInfoPlugin();
    bool isPhysical = true; // Safe default

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        isPhysical = androidInfo.isPhysicalDevice;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        isPhysical = iosInfo.isPhysicalDevice;
      }
    } catch (e) {
      debugPrint("[ScannerScreen] Device check failed: $e");
    }

    if (mounted) {
      setState(() => _isPhysicalDevice = isPhysical);
    }
  }

  Future<void> _startScanning() async {
    setState(() => _canScan = true);

    if (_controller != null && _controller!.value.isInitialized) {
      // If already initialized but stopped, strictly ensuring stream is on might be needed,
      // but typically we just set flag. If stream was stopped on stopScanning, we might need restart.
      if (!_controller!.value.isStreamingImages) {
        try {
          await _controller!.startImageStream(_processImage);
        } catch (e) {
          debugPrint("Error restarting stream: $e");
        }
      }
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final firstCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      firstCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;

      setState(() => _isInit = true);
      _controller!.startImageStream(_processImage);
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  Future<void> _stopScanning() async {
    setState(() {
      _canScan = false;
      _isInit = false;
    });
    // We optionally keep the controller alive but stop the stream to save battery?
    // Or dispose completely. The previous logic disposed it. Let's stick to disposal for "Stop".
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }

  Future<void> _processImage(CameraImage image) async {
    if (_isProcessing || !_isInit || !_canScan) return;
    _isProcessing = true;

    try {
      final inputImage = CameraUtils.convertCameraImageToInputImage(
          image, _controller!.description);
      if (inputImage == null) return;

      await _processBarcode(inputImage);
    } catch (e) {
      debugPrint("Scan error: $e");
    } finally {
      if (mounted) _isProcessing = false;
    }
  }

  Future<void> _processBarcode(InputImage inputImage) async {
    final barcodes = await _barcodeScanner.processImage(inputImage);
    if (barcodes.isNotEmpty) {
      final barcode = barcodes.first.rawValue;
      if (barcode != null) {
        _canScan = false; // Stop scanning once found
        await ref.read(scanControllerProvider).onBarcodeScanned(barcode);
      }
    }
  }

  void _showTestBarcodes() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow full height if needed
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Select a Test Product",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        _buildTestTile("Wonderful Pistachios", "0014113910446",
                            Icons.grass, "Snack/Nut"),
                        _buildTestTile("Organic Soymilk", "0036632002773",
                            Icons.water_drop, "Beverage"),
                        _buildTestTile(
                            "Nutella", "3017620422003", Icons.cookie, "Spread"),
                        const Divider(),
                        _buildTestTile("Coca-Cola 2L", "5449000009067",
                            Icons.local_drink, "Soda"),
                        _buildTestTile("Heinz Ketchup", "0013000004664",
                            Icons.soup_kitchen, "Condiment"),
                        _buildTestTile("Barilla Spaghetti", "0076808006575",
                            Icons.dining, "Pasta/Grain"),
                        _buildTestTile("Oreos", "0044000071851",
                            Icons.cookie_outlined, "Sweet/Cookie"),
                        const Divider(),
                        _buildTestTile("Chobani Greek Yogurt", "0894700010137",
                            Icons.icecream, "Dairy"),
                        _buildTestTile("DiGiorno Pepperoni Pizza",
                            "0071921003395", Icons.local_pizza, "Frozen/Meal"),
                        _buildTestTile(
                            "Nature's Own Wheat Bread",
                            "0072250013871",
                            Icons.breakfast_dining,
                            "Grain/Bread"),
                        _buildTestTile("Campbell's Soup", "737628064502",
                            Icons.soup_kitchen, "Canned/Meal"),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTestTile(
      String name, String barcode, IconData icon, String subtitle) {
    return ListTile(
      leading: Icon(icon),
      title: Text("$name ($barcode)"),
      subtitle: Text(subtitle),
      onTap: () {
        Navigator.pop(context);
        ref.read(scanControllerProvider).onBarcodeScanned(barcode);
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _stopScanning();
    } else if (state == AppLifecycleState.resumed) {
      // If we want to auto-resume scanning when app comes back,
      // we would call _startScanning() here.
      // For manual trigger, we don't auto-resume.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(scanResultProvider, (previous, next) {
      if (next != null) {
        context.go('/product');
      }
    });

    ref.listen(scanMessageProvider, (previous, next) {
      if (next != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next), backgroundColor: Colors.red),
        );
        ref.read(scanMessageProvider.notifier).state = null;
        setState(() => _canScan =
            false); // Stop scanning on error so usage requires re-tap
      }
    });

    // SHOW "TAP TO SCAN" IF NOT SCANNING
    if (!_canScan || !_isInit || _controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_scanner,
                      size: 80, color: Colors.white54),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _startScanning,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Tap to Scan"),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16)),
                  ),
                  if (!_isPhysicalDevice) ...[
                    const SizedBox(height: 20),
                    TextButton.icon(
                      onPressed: _showTestBarcodes,
                      icon: const Icon(Icons.qr_code, color: Colors.white70),
                      label: const Text("Test with Barcodes",
                          style: TextStyle(color: Colors.white70)),
                    ),
                  ]
                ],
              ),
            ),
            _buildTopControls(),
          ],
        ),
      );
    }

    // SHOW CAMERA
    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(_controller!),
          _buildOverlay(),
          _buildTopControls(),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: FloatingActionButton.extended(
          onPressed: _stopScanning,
          backgroundColor: Colors.red,
          icon: const Icon(Icons.stop),
          label: const Text("Stop"),
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return Positioned(
      top: 50,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                _stopScanning();
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextButton.icon(
              onPressed: _showSettingsDialog,
              icon: const Icon(Icons.settings, color: Colors.white, size: 20),
              label: const Text(
                "Settings",
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    final profile = ref.read(userProfileProvider).valueOrNull;
    final currentZip = profile?.defaultZipCode ?? '';
    final currentDiets = profile?.dietaryPreferences ?? [];

    final controller = TextEditingController(text: currentZip);
    var selectedDiets = List<DietRestriction>.from(currentDiets);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Settings & Preferences"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Local Prices",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "ZIP Code",
                    hintText: "e.g. 90210",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Health Indicator",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ...DietRestriction.values.map((diet) {
                  return CheckboxListTile(
                    title: Text(diet.displayName,
                        style: const TextStyle(fontSize: 14)),
                    value: selectedDiets.contains(diet),
                    onChanged: (bool? checked) {
                      setState(() {
                        if (checked == true) {
                          selectedDiets.add(diet);
                        } else {
                          selectedDiets.remove(diet);
                        }
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                ref.read(userProfileProvider.notifier).updateProfile(
                    zip: controller.text.trim(), diets: selectedDiets);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black, foregroundColor: Colors.white),
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return Positioned.fill(
      child: Center(
        child: Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.4), width: 2),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.qr_code_scanner, color: Colors.white, size: 54),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.black.withValues(alpha: 0.3),
                    child: const Text(
                      "Scanning Barcode...",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
