import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';

// Classe auxiliar para o resultado do picker
class PickedImage {
  final Uint8List bytes;
  final String extension; 

  PickedImage({required this.bytes, required this.extension});
}

class UploadResult {
  final String downloadUrl;
  final String filePath;

  UploadResult({required this.downloadUrl, required this.filePath});
}

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  /// Seleciona a imagem e retorna os BYTES (compatível com Web e Mobile)
  Future<PickedImage?> pickImageForPreview() async {
    try {
      // Usa o ImagePicker em vez do FilePicker
      final ImagePicker picker = ImagePicker();
      
      // Abre galeria
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return null;

      // Lê os bytes
      Uint8List bytes = await image.readAsBytes();
      
      // Pega a extensão (pequeno ajuste pois XFile não dá a extensão direta às vezes)
      String extension = image.name.split('.').last;
      if (extension.isEmpty) extension = 'jpg';

      return PickedImage(bytes: bytes, extension: extension);

    } catch (e) {
      print("[StorageService] Erro: $e");
      return null;
    }
  }

  /// Faz o upload dos bytes para o Firebase Storage
  Future<UploadResult?> uploadImage({
    required Uint8List fileBytes,
    required String fileName,
    required String fileExtension,
    required Function(double) onProgress,
  }) async {
    try {
      final String uniqueFileName = '${_uuid.v4()}.$fileExtension';
      final String filePath = 'component_images/$uniqueFileName';
      
      print("[StorageService] Iniciando upload para: $filePath");

      Reference ref = _storage.ref().child(filePath);
      
      // Configura metadados para garantir que o navegador entenda que é uma imagem
      SettableMetadata metadata = SettableMetadata(
        contentType: 'image/$fileExtension',
      );

      // putData funciona na Web e Mobile
      UploadTask uploadTask = ref.putData(fileBytes, metadata);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.totalBytes > 0) {
          final double progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        }
      });

      await uploadTask;
      String downloadUrl = await ref.getDownloadURL();
      
      print("[StorageService] Upload concluído. URL: $downloadUrl");

      return UploadResult(downloadUrl: downloadUrl, filePath: filePath);

    } catch (e) {
      print("[StorageService] ERRO NO UPLOAD: $e");
      // Verifica erro comum de CORS
      if (e.toString().contains('XMLHttpRequest')) {
        print("⚠️ ERRO DE CORS DETECTADO: Você precisa configurar o CORS no Google Cloud Console.");
      }
      return null;
    }
  }

  Future<void> deleteImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return;
    try {
      Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      print("[StorageService] Imagem deletada: $imageUrl");
    } catch (e) {
      print("[StorageService] Erro ao deletar (pode não existir mais): $e");
    }
  }
}