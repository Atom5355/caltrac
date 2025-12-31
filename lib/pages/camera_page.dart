import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/gemini_service.dart';
import '../services/supabase_service.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _contextController = TextEditingController();
  XFile? _imageFile;
  Uint8List? _imageBytes;
  bool _isAnalyzing = false;
  NutritionAnalysis? _analysis;
  String? _error;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _contextController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageFile = image;
          _imageBytes = bytes;
          _analysis = null;
          _error = null;
        });
      }
    } catch (e) {
      setState(() => _error = 'Failed to pick image: $e');
    }
  }

  Future<void> _analyzeImage() async {
    if (_imageBytes == null) return;

    setState(() {
      _isAnalyzing = true;
      _error = null;
    });

    try {
      final base64Image = base64Encode(_imageBytes!);
      final mimeType = _imageFile?.mimeType ?? 'image/jpeg';
      final additionalContext = _contextController.text.trim();

      final analysis = await GeminiService.analyzeFood(
        base64Image,
        mimeType: mimeType,
        additionalContext: additionalContext.isNotEmpty
            ? additionalContext
            : null,
      );

      setState(() {
        _analysis = analysis;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _analyzeTextOnly() async {
    final description = _contextController.text.trim();
    if (description.isEmpty) {
      setState(() => _error = 'Please describe the food you want to analyze');
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _error = null;
    });

    try {
      final analysis = await GeminiService.analyzeFoodTextOnly(description);

      setState(() {
        _analysis = analysis;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _saveEntry() async {
    if (_analysis == null || _analysis!.hasError) return;

    try {
      await SupabaseService.logFood(
        foodName: _analysis!.foodName ?? 'Unknown Food',
        calories: _analysis!.calories,
        protein: _analysis!.protein,
        carbs: _analysis!.carbs,
        fat: _analysis!.fat,
        notes: _analysis!.notes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Food logged successfully!'),
            backgroundColor: const Color(0xFF00E676),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0E21), Color(0xFF1A1A2E), Color(0xFF0A0E21)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildImagePreview(),
                      const SizedBox(height: 16),
                      _buildContextInput(),
                      const SizedBox(height: 24),
                      if (_isAnalyzing) _buildAnalyzingIndicator(),
                      if (_error != null) _buildErrorCard(),
                      if (_analysis != null && !_isAnalyzing)
                        _buildAnalysisCard(),
                      const SizedBox(height: 24),
                      _buildCaptureButtons(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1D1E33),
                border: Border.all(
                  color: const Color(0xFF00E676).withOpacity(0.3),
                ),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Color(0xFF00E676),
                size: 20,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Scan Food',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF1D1E33),
        border: Border.all(color: const Color(0xFF00E676).withOpacity(0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: _imageBytes != null
            ? Image.memory(_imageBytes!, fit: BoxFit.cover)
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Icon(
                            Icons.restaurant_menu,
                            size: 64,
                            color: const Color(0xFF00E676).withOpacity(0.5),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Take a photo or describe your food',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Image is optional - you can use text only',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildContextInput() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1D1E33),
        border: Border.all(color: const Color(0xFF00E676).withOpacity(0.2)),
      ),
      child: TextField(
        controller: _contextController,
        style: const TextStyle(color: Colors.white),
        maxLines: 2,
        decoration: InputDecoration(
          hintText: 'Describe food: "Big Mac", "2 eggs scrambled", etc.',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.restaurant,
            color: const Color(0xFF00E676).withOpacity(0.5),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        onChanged: (_) {
          // Rebuild to update button state and clear analysis
          setState(() {
            if (_analysis != null) {
              _analysis = null;
            }
          });
        },
      ),
    );
  }

  Widget _buildAnalyzingIndicator() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1D1E33),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF00E676),
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF00E676), Color(0xFF00BFA5)],
            ).createShader(bounds),
            child: const Text(
              'Analyzing with AI...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Identifying food and calculating nutrition',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.red.withOpacity(0.1),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Analysis Failed',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _analyzeImage,
            child: const Text(
              'Retry',
              style: TextStyle(color: Color(0xFF00E676)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard() {
    if (_analysis == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D1E33), Color(0xFF2D2D44)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E676).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00E676).withOpacity(0.15),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF00E676),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _analysis!.foodName ?? 'Identified Food',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (_analysis!.servingSize != null)
                      Text(
                        _analysis!.servingSize!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (_analysis!.confidence != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _getConfidenceColor(
                      _analysis!.confidence!,
                    ).withOpacity(0.15),
                  ),
                  child: Text(
                    _analysis!.confidence!,
                    style: TextStyle(
                      color: _getConfidenceColor(_analysis!.confidence!),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          // Calories
          _buildNutrientRow(
            'Calories',
            '${_analysis!.calories}',
            'kcal',
            const Color(0xFF00E676),
            isMain: true,
          ),
          const SizedBox(height: 20),
          // Macros
          Row(
            children: [
              Expanded(
                child: _buildMacroChip(
                  'Protein',
                  '${_analysis!.protein.toStringAsFixed(1)}g',
                  const Color(0xFF00E676),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMacroChip(
                  'Carbs',
                  '${_analysis!.carbs.toStringAsFixed(1)}g',
                  const Color(0xFF00BFA5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMacroChip(
                  'Fat',
                  '${_analysis!.fat.toStringAsFixed(1)}g',
                  const Color(0xFF64FFDA),
                ),
              ),
            ],
          ),
          if (_analysis!.notes != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withOpacity(0.05),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.white.withOpacity(0.4),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _analysis!.notes!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveEntry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Add to Food Log',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientRow(
    String label,
    String value,
    String unit,
    Color color, {
    bool isMain = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: isMain ? 48 : 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          unit,
          style: TextStyle(
            fontSize: isMain ? 20 : 14,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildMacroChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildCaptureButton(
                Icons.photo_library,
                'Gallery',
                () => _pickImage(ImageSource.gallery),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildCaptureButton(
                Icons.camera_alt,
                'Camera',
                () => _pickImage(ImageSource.camera),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Text-only analyze button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isAnalyzing || _contextController.text.trim().isEmpty
                ? null
                : _analyzeTextOnly,
            icon: const Icon(Icons.text_fields),
            label: const Text('Analyze with Text Only'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF00E676),
              side: BorderSide(
                color: _contextController.text.trim().isEmpty
                    ? Colors.grey.withOpacity(0.3)
                    : const Color(0xFF00E676).withOpacity(0.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        if (_contextController.text.trim().isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Enter food description above to use text-only mode',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCaptureButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: _isAnalyzing ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF1D1E33),
          border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: _isAnalyzing ? Colors.grey : const Color(0xFF00E676),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: _isAnalyzing ? Colors.grey : Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getConfidenceColor(String confidence) {
    switch (confidence.toLowerCase()) {
      case 'high':
        return const Color(0xFF00E676);
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
