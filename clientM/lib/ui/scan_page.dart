import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:developer' as devtools;
import 'package:wolfbud/constants.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({Key? key}) : super(key: key);

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  File? filePath;
  String label = '';
  double confidence = 0.0;
  bool hasRecognition = false;
  List<Map<String, String>> similarProducts = []; // Danh sách sản phẩm tương tự

  @override
  void initState() {
    super.initState();
    _tfLteInit();
  }

  Future<void> _tfLteInit() async {
    String? res = await Tflite.loadModel(
      model: "assets/mobilenet_model.tflite",
      labels: "assets/labels.txt",
      numThreads: 1,
      isAsset: true,
      useGpuDelegate: false,
    );
    if (res == null) {
      devtools.log("Model not loaded");
    }
  }

  pickImageGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    var imageMap = File(image.path);
    setState(() {
      filePath = imageMap;
    });

    _runModelOnImage(image.path);
  }

  pickImageCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image == null) return;

    var imageMap = File(image.path);
    setState(() {
      filePath = imageMap;
    });

    _runModelOnImage(image.path);
  }

  Future<void> _runModelOnImage(String imagePath) async {
    var recognitions = await Tflite.runModelOnImage(
      path: imagePath,
      imageMean: 0.0,
      imageStd: 255.0,
      numResults: 2,
      threshold: 0.2,
      asynch: true,
    );

    if (recognitions == null || recognitions.isEmpty) {
      devtools.log("recognitions is Null");
      return;
    }

    devtools.log(recognitions.toString());
    setState(() {
      confidence = (recognitions[0]['confidence'] * 100);
      label = recognitions[0]['label'].toString();
      hasRecognition = true; // Đã nhận diện xong

      // Gọi API để lấy các sản phẩm tương tự
      fetchSimilarProducts(label).then((products) {
        devtools.log("Fetched similar product: $products");
        setState(() {
          similarProducts = products; // Cập nhật danh sách sản phẩm tương tự
        });
      }).catchError((error) {
        devtools.log("Error fetching similar products: $error");
      });
    });
  }

  Future<List<Map<String, String>>> fetchSimilarProducts(String flowerName) async {
    devtools.log("Fetching similar products for flower: $flowerName");
    final response = await http.get(Uri.parse('http://10.0.2.2:3000/api/products/byName?flowerName=$flowerName'));

    devtools.log("API response status: ${response.statusCode}");
    if (response.statusCode == 200) {
      final List<dynamic> productData = json.decode(response.body)['data'];
      return productData.map((data) {
        return {
          'name': data['product_name'] as String,
          'image': (data['product_imgs'] != null && data['product_imgs'].isNotEmpty)
              ? data['product_imgs'][0] as String // Lấy hình ảnh đầu tiên nếu có
              : '', // Nếu không có hình ảnh, trả về chuỗi rỗng
        };
      }).toList();
    } else {
      devtools.log("Failed to load products: ${response.body}");
      throw Exception('Failed to load products');
    }
  }

  @override
  void dispose() {
    super.dispose();
    Tflite.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Constants.primaryColor,
        title: const Text("Predict Flower"),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Card(
                elevation: 20,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: 300,
                  child: Column(
                    children: [
                      const SizedBox(height: 18),
                      Container(
                        height: 280,
                        width: 280,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          image: const DecorationImage(
                            image: AssetImage('assets/upload.png'),
                          ),
                        ),
                        child: filePath == null
                            ? const Text('')
                            : Image.file(
                                filePath!,
                                fit: BoxFit.fill,
                              ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () {},
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Hiển thị các sản phẩm tương tự sau khi nhận diện
              if (hasRecognition && similarProducts.isNotEmpty) // Kiểm tra danh sách sản phẩm
                Column(
                  children: [
                    const Text(
                      "Similar Flowers",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: similarProducts.length,
                        itemBuilder: (context, index) {
                          return similarFlowerCard(
                            similarProducts[index]['name']!,
                            similarProducts[index]['image']!,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),

              ElevatedButton(
                onPressed: pickImageCamera,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                  backgroundColor: Constants.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Chọn từ máy ảnh"),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: pickImageGallery,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                  backgroundColor: Constants.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Chọn từ bộ sưu tập"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget similarFlowerCard(String name, String imagePath) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          if (imagePath.isNotEmpty) // Kiểm tra hình ảnh có hợp lệ không
            Image.network(imagePath, width: 100, height: 80, fit: BoxFit.cover)
          else
            Container(
              width: 100,
              height: 80,
              color: Colors.grey,
              child: const Icon(Icons.image_not_supported), // Hiển thị biểu tượng nếu không có hình ảnh
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(name),
          ),
        ],
      ),
    );
  }
}




// // import 'dart:typed_data';
// // import 'dart:io';
// // import 'package:flutter/material.dart';
// // import 'package:image_picker/image_picker.dart';
// // import 'package:tflite_flutter/tflite_flutter.dart';
// // import 'package:wolfbud/constants.dart';

// // class ScanPage extends StatefulWidget {
// //   const ScanPage({Key? key}) : super(key: key);

// //   @override
// //   State<ScanPage> createState() => _ScanPageState();
// // }

// // class _ScanPageState extends State<ScanPage> {
// //   final ImagePicker _picker = ImagePicker();
// //   Interpreter? _interpreter;
// //   String? _imagePath;
// //   String? _prediction;
// //   bool _isLoading = false;

// //   @override
// //   void initState() {
// //     super.initState();
// //     _loadModel();
// //   }

// //   Future<void> _loadModel() async {
// //     try {
// //       final interpreterOptions = InterpreterOptions();
// //       _interpreter = await Interpreter.fromAsset(
// //         'modelf.tflite',
// //         options: interpreterOptions,
// //       );
// //       print("Model loaded successfully.");
// //     } catch (e) {
// //       print("Failed to load model: $e");
// //     }
// //   }

// //   Future<void> _pickImageFromCamera() async {
// //     final XFile? image = await _picker.pickImage(source: ImageSource.camera);
// //     if (image != null) {
// //       setState(() {
// //         _imagePath = image.path;
// //       });
// //       await _predictImage(image.path);
// //     }
// //   }

// //   Future<void> _pickImageFromGallery() async {
// //     final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
// //     if (image != null) {
// //       setState(() {
// //         _imagePath = image.path;
// //       });
// //       await _predictImage(image.path);
// //     }
// //   }

// //   Future<void> _predictImage(String imagePath) async {
// //     if (_interpreter == null) {
// //       setState(() {
// //         _prediction = "Model not loaded";
// //       });
// //       return;
// //     }

// //     setState(() {
// //       _isLoading = true;
// //     });

// //     try {
// //       var inputImage = await _preprocessImage(imagePath);
// //       var inputBuffer = inputImage.buffer.asFloat32List();
// //       var outputBuffer = List.filled(1, 0.0).reshape([1]);

// //       _interpreter!.run(inputBuffer, outputBuffer);
// //       setState(() {
// //         _prediction = mapOutputToLabel(outputBuffer[0]);
// //       });
// //     } catch (e) {
// //       setState(() {
// //         _prediction = "Prediction error: $e";
// //       });
// //     } finally {
// //       setState(() {
// //         _isLoading = false;
// //       });
// //     }
// //   }

// //   Future<Uint8List> _preprocessImage(String imagePath) async {
// //     final imageFile = File(imagePath);
// //     // Đọc ảnh vào Uint8List
// //     final imageBytes = await imageFile.readAsBytes();

// //     // Giả sử kích thước đầu vào là 224x224, bạn cần resize ảnh ở đây.
// //     // Cần một thư viện để resize ảnh, hoặc bạn có thể thực hiện việc này trong môi trường khác.
// //     // Ở đây, bạn cần phải chuyển đổi ảnh sang Float32List với kích thước 224x224x3.

// //     // Placeholder: Trả về một danh sách rỗng cho tới khi bạn thực hiện xong việc resize
// //     return Uint8List(224 * 224 * 3);
// //   }

// //   String mapOutputToLabel(double output) {
// //     switch (output.round()) {
// //       case 0:
// //         return "Label 0"; // Thay đổi thành nhãn tương ứng
// //       case 1:
// //         return "Label 1"; // Thay đổi thành nhãn tương ứng
// //       case 2:
// //         return "Label 2"; // Thay đổi thành nhãn tương ứng
// //       case 3:
// //         return "Label 3"; // Thay đổi thành nhãn tương ứng
// //       case 4:
// //         return "Label 4"; // Thay đổi thành nhãn tương ứng
// //       default:
// //         return "Unknown label";
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     Size size = MediaQuery.of(context).size;
// //     return Scaffold(
// //       appBar: AppBar(
// //         title: const Text('Tìm kiếm bằng hình ảnh'),
// //         backgroundColor: Constants.primaryColor,
// //       ),
// //       body: Stack(
// //         children: [
// //           Positioned(
// //             top: 50,
// //             left: 20,
// //             right: 20,
// //             child: Row(
// //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //               children: [
// //                 GestureDetector(
// //                   onTap: () {
// //                     Navigator.pop(context);
// //                   },
// //                   child: Container(
// //                     height: 40,
// //                     width: 40,
// //                     decoration: BoxDecoration(
// //                       borderRadius: BorderRadius.circular(25),
// //                       color: Constants.primaryColor.withOpacity(.15),
// //                     ),
// //                     child: Icon(
// //                       Icons.close,
// //                       color: Constants.primaryColor,
// //                     ),
// //                   ),
// //                 ),
// //                 GestureDetector(
// //                   onTap: () {
// //                     debugPrint('favorite');
// //                   },
// //                   child: Container(
// //                     height: 40,
// //                     width: 40,
// //                     decoration: BoxDecoration(
// //                       borderRadius: BorderRadius.circular(25),
// //                       color: Constants.primaryColor.withOpacity(.15),
// //                     ),
// //                     child: IconButton(
// //                       onPressed: () {},
// //                       icon: Icon(
// //                         Icons.share,
// //                         color: Constants.primaryColor,
// //                       ),
// //                     ),
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),
// //           Positioned(
// //             top: 100,
// //             right: 20,
// //             left: 20,
// //             child: Container(
// //               width: size.width * .8,
// //               height: size.height * .8,
// //               padding: const EdgeInsets.all(20),
// //               child: Center(
// //                 child: Column(
// //                   mainAxisAlignment: MainAxisAlignment.center,
// //                   crossAxisAlignment: CrossAxisAlignment.center,
// //                   children: [
// //                     if (_imagePath == null)
// //                       Image.asset(
// //                         'assets/images/code-scan.png',
// //                         height: 100,
// //                       )
// //                     else if (Platform.isAndroid || Platform.isIOS)
// //                       Image.file(
// //                         File(_imagePath!),
// //                         height: 100,
// //                       )
// //                     else
// //                       const Text('Không thể hiển thị hình ảnh trên nền tảng này'),
// //                     const SizedBox(height: 20),
// //                     if (_isLoading)
// //                       CircularProgressIndicator()
// //                     else
// //                       Text(
// //                         _prediction ?? '',
// //                         style: TextStyle(
// //                           color: Constants.primaryColor.withOpacity(.80),
// //                           fontWeight: FontWeight.w500,
// //                           fontSize: 20,
// //                         ),
// //                       ),
// //                     const SizedBox(height: 40),
// //                     ElevatedButton.icon(
// //                       onPressed: _pickImageFromCamera,
// //                       icon: const Icon(Icons.camera),
// //                       label: const Text('Tìm kiếm bằng máy ảnh'),
// //                       style: ElevatedButton.styleFrom(
// //                         backgroundColor: Constants.primaryColor,
// //                       ),
// //                     ),
// //                     const SizedBox(height: 20),
// //                     ElevatedButton.icon(
// //                       onPressed: _pickImageFromGallery,
// //                       icon: const Icon(Icons.photo_library),
// //                       label: const Text('Tìm kiếm trong bộ sưu tập'),
// //                       style: ElevatedButton.styleFrom(
// //                         backgroundColor: Constants.primaryColor,
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter_tflite/flutter_tflite.dart';
// import 'package:image_picker/image_picker.dart';
// import 'dart:developer' as devtools;

// import 'package:wolfbud/constants.dart';
// import 'package:http/http.dart';

// class ScanPage extends StatefulWidget {
//   const ScanPage({Key? key}) : super(key: key);

//   @override
//   State<ScanPage> createState() => _ScanPageState();
// }

// class _ScanPageState extends State<ScanPage> {
//   File? filePath;
//   String label = '';
//   double confidence = 0.0;

//   @override
//   void initState() {
//     super.initState();
//     _tfLteInit();
//   }

//   Future<void> _tfLteInit() async {
//     String? res = await Tflite.loadModel(
//       model: "assets/mobilenet_model.tflite",
//       labels: "assets/labels.txt",
//       numThreads: 1,
//       isAsset: true,
//       useGpuDelegate: false,
//     );
//     if (res == null) {
//       devtools.log("Model not loaded");
//     }
//   }

//   pickImageGallery() async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? image = await picker.pickImage(source: ImageSource.gallery);

//     if (image == null) return;

//     var imageMap = File(image.path);
//     setState(() {
//       filePath = imageMap;
//     });

//     _runModelOnImage(image.path);
//   }

//   pickImageCamera() async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? image = await picker.pickImage(source: ImageSource.camera);

//     if (image == null) return;

//     var imageMap = File(image.path);
//     setState(() {
//       filePath = imageMap;
//     });

//     _runModelOnImage(image.path);
//   }

//   Future<void> _runModelOnImage(String imagePath) async {
//     var recognitions = await Tflite.runModelOnImage(
//       path: imagePath,
//       imageMean: 0.0,
//       imageStd: 255.0,
//       numResults: 2,
//       threshold: 0.2,
//       asynch: true,
//     );

//     if (recognitions == null) {
//       devtools.log("recognitions is Null");
//       return;
//     }

//     devtools.log(recognitions.toString());
//     setState(() {
//       confidence = (recognitions[0]['confidence'] * 100);
//       label = recognitions[0]['label'].toString();
//     });
//   }

//   Future<void> _getPlantDetailAndNavigate(String plantName) async {
//     // final response = await http.get(Uri.parse("http://10.0.2.2:3000/api/product/$plantName"));

//     // if(response.statusCode == 200){
//     //   var plantData =
//     // }
//   }

//   @override
//   void dispose() {
//     super.dispose();
//     Tflite.close();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Constants.primaryColor,
//         title: const Text("Predict Flower"),
//       ),
//       body: SingleChildScrollView(
//         child: Center(
//           child: Column(
//             children: [
//               const SizedBox(height: 12),
//               Card(
//                 elevation: 20,
//                 clipBehavior: Clip.hardEdge,
//                 child: SizedBox(
//                   width: 300,
//                   child: SingleChildScrollView(
//                     child: Column(
//                       children: [
//                         const SizedBox(height: 18),
//                         Container(
//                           height: 280,
//                           width: 280,
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(12),
//                             image: const DecorationImage(
//                               image: AssetImage('assets/upload.png'),
//                             ),
//                           ),
//                           child: filePath == null
//                               ? const Text('')
//                               : Image.file(
//                                   filePath!,
//                                   fit: BoxFit.fill,
//                                 ),
//                         ),
//                         const SizedBox(height: 12),
//                         Padding(
//                           padding: const EdgeInsets.all(8.0),
//                           child: Column(
//                             children: [
//                               GestureDetector(
//                                 onTap: () {},
//                                 child: Text(
//                                   label,
//                                   style: const TextStyle(
//                                     fontSize: 18,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                               ),
//                               const SizedBox(height: 12),
//                               // Text(
//                               //   "The Accuracy is ${confidence.toStringAsFixed(0)}%",
//                               //   style: const TextStyle(
//                               //     fontSize: 18,
//                               //   ),
//                               // ),
//                               // const SizedBox(height: 12),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 8),
//               ElevatedButton(
//                 onPressed: pickImageCamera,
//                 style: ElevatedButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 30,
//                     vertical: 10,
//                   ),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(13),
//                   ),
//                   backgroundColor: Constants.primaryColor,
//                   foregroundColor: Colors.white,
//                 ),
//                 child: const Text("Chọn từ máy ảnh"),
//               ),
//               const SizedBox(height: 8),
//               ElevatedButton(
//                 onPressed: pickImageGallery,
//                 style: ElevatedButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 30,
//                     vertical: 10,
//                   ),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(13),
//                   ),
//                   backgroundColor: Constants.primaryColor,
//                   foregroundColor: Colors.white,
//                 ),
//                 child: const Text("Chọn từ bộ sưu tập"),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }


//nhan hoa roi hien thi
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter_tflite/flutter_tflite.dart';
// import 'package:image_picker/image_picker.dart';
// import 'dart:developer' as devtools;
// import 'package:wolfbud/constants.dart';

// class ScanPage extends StatefulWidget {
//   const ScanPage({Key? key}) : super(key: key);

//   @override
//   State<ScanPage> createState() => _ScanPageState();
// }

// class _ScanPageState extends State<ScanPage> {
//   File? filePath;
//   String label = '';
//   double confidence = 0.0;
//   bool hasRecognition = false;

//   @override
//   void initState() {
//     super.initState();
//     _tfLteInit();
//   }

//   Future<void> _tfLteInit() async {
//     String? res = await Tflite.loadModel(
//       model: "assets/mobilenet_model.tflite",
//       labels: "assets/labels.txt",
//       numThreads: 1,
//       isAsset: true,
//       useGpuDelegate: false,
//     );
//     if (res == null) {
//       devtools.log("Model not loaded");
//     }
//   }

//   pickImageGallery() async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? image = await picker.pickImage(source: ImageSource.gallery);

//     if (image == null) return;

//     var imageMap = File(image.path);
//     setState(() {
//       filePath = imageMap;
//     });

//     _runModelOnImage(image.path);
//   }

//   pickImageCamera() async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? image = await picker.pickImage(source: ImageSource.camera);

//     if (image == null) return;

//     var imageMap = File(image.path);
//     setState(() {
//       filePath = imageMap;
//     });

//     _runModelOnImage(image.path);
//   }

//   Future<void> _runModelOnImage(String imagePath) async {
//     var recognitions = await Tflite.runModelOnImage(
//       path: imagePath,
//       imageMean: 0.0,
//       imageStd: 255.0,
//       numResults: 2,
//       threshold: 0.2,
//       asynch: true,
//     );

//     if (recognitions == null) {
//       devtools.log("recognitions is Null");
//       return;
//     }

//     devtools.log(recognitions.toString());
//     setState(() {
//       confidence = (recognitions[0]['confidence'] * 100);
//       label = recognitions[0]['label'].toString();
//       hasRecognition = true; // Set to true when recognition is successful
//     });
//   }

//   @override
//   void dispose() {
//     super.dispose();
//     Tflite.close();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Constants.primaryColor,
//         title: const Text("Predict Flower"),
//       ),
//       body: SingleChildScrollView(
//         child: Center(
//           child: Column(
//             children: [
//               const SizedBox(height: 12),
//               Card(
//                 elevation: 20,
//                 clipBehavior: Clip.hardEdge,
//                 child: SizedBox(
//                   width: 300,
//                   child: Column(
//                     children: [
//                       const SizedBox(height: 18),
//                       Container(
//                         height: 280,
//                         width: 280,
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(12),
//                           image: const DecorationImage(
//                             image: AssetImage('assets/upload.png'),
//                           ),
//                         ),
//                         child: filePath == null
//                             ? const Text('')
//                             : Image.file(
//                                 filePath!,
//                                 fit: BoxFit.fill,
//                               ),
//                       ),
//                       const SizedBox(height: 12),
//                       Padding(
//                         padding: const EdgeInsets.all(8.0),
//                         child: Column(
//                           children: [
//                             GestureDetector(
//                               onTap: () {},
//                               child: Text(
//                                 label,
//                                 style: const TextStyle(
//                                   fontSize: 18,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ),
//                             const SizedBox(height: 12),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 12),

//               // Conditionally render the similar flowers section based on recognition status
//               if (hasRecognition)
//                 Column(
//                   children: [
//                     const Text(
//                       "Similar Flowers",
//                       style: TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     SizedBox(
//                       height: 120,
//                       child: ListView(
//                         scrollDirection: Axis.horizontal,
//                         children: [
//                           similarFlowerCard(
//                               'Hoa Hồng Đỏ', 'assets/images/hoahong.jpg'),
//                           similarFlowerCard('Hoa Lan hồ điệp tím',
//                               'assets/images/hoahong.jpg'),
//                           similarFlowerCard('Hoa Lan hồ điệp trắng',
//                               'assets/images/hoahong.jpg'),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 12),
//                   ],
//                 ),

//               ElevatedButton(
//                 onPressed: pickImageCamera,
//                 style: ElevatedButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 30,
//                     vertical: 10,
//                   ),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(13),
//                   ),
//                   backgroundColor: Constants.primaryColor,
//                   foregroundColor: Colors.white,
//                 ),
//                 child: const Text("Chọn từ máy ảnh"),
//               ),
//               const SizedBox(height: 8),
//               ElevatedButton(
//                 onPressed: pickImageGallery,
//                 style: ElevatedButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 30,
//                     vertical: 10,
//                   ),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(13),
//                   ),
//                   backgroundColor: Constants.primaryColor,
//                   foregroundColor: Colors.white,
//                 ),
//                 child: const Text("Chọn từ bộ sưu tập"),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget similarFlowerCard(String name, String imagePath) {
//     return Card(
//       margin: const EdgeInsets.symmetric(horizontal: 8),
//       child: Column(
//         children: [
//           Image.asset(imagePath, width: 100, height: 80, fit: BoxFit.cover),
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Text(name),
//           ),
//         ],
//       ),
//     );
//   }
// }
