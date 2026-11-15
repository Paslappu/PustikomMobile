import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qrscan/models/perangkat_model.dart';
import 'package:qrscan/pages/base.dart';
import 'package:qrscan/pages/webview.dart';
import 'package:qrscan/services/database_service.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class RincianPerangkat extends StatefulWidget {
  final int? dbId;
  final dynamic idPerangkat;
  final bool isEditing;
  final String? initialName;
  final String? scrapedMapUrl;
  final String? scrapedModelUrl;
  final String? status;
  final List<dynamic>? scrapedHistory;
  final String? originalUrl;

  const RincianPerangkat({
    super.key,
    this.dbId,
    required this.idPerangkat,
    required this.isEditing,
    this.initialName,
    this.originalUrl,
    this.scrapedHistory,
    this.scrapedMapUrl,
    this.scrapedModelUrl,
    this.status,
  });

  @override
  State<RincianPerangkat> createState() => _RincianPerangkatState();
}

class _RincianPerangkatState extends State<RincianPerangkat> {
  final DatabaseService databaseService = DatabaseService.instance;
  bool isEdit = false;
  int selectedHistoryIndex =
      0; // Tracks which history row is selected for the map dot
  List<Color> _randomColors = [];
  String _getDeviceUrl(String? url) {
    if (url == null || url.isEmpty) return "";
    String fixedUrl = url;
    try {
      if (fixedUrl.contains('localhost') || fixedUrl.contains('0.0.0.0')) {
        String replaceHost = '127.0.0.1';
        if (widget.originalUrl != null && widget.originalUrl!.isNotEmpty) {
          final parsed = Uri.tryParse(widget.originalUrl!);
          if (parsed != null && parsed.host.isNotEmpty) {
            replaceHost = parsed.host;
          }
        }
        fixedUrl = fixedUrl
            .replaceAll('localhost', replaceHost)
            .replaceAll('0.0.0.0', replaceHost);
      }
    } catch (e) {
      // ignore and use original url
    }

    print("DEBUG: Mobile app is requesting model from -> $fixedUrl");
    return fixedUrl;
  }

  late TextEditingController _namaController;
  late TextEditingController _tanggalController;
  late TextEditingController _gedungController;
  late TextEditingController _portController;
  late TextEditingController _locationController;
  late TextEditingController _coordinateController;

  @override
  void initState() {
    super.initState();
    isEdit = widget.isEditing;
    _namaController = TextEditingController(
      text: widget.initialName ?? widget.idPerangkat?.toString() ?? "",
    );
    _tanggalController = TextEditingController(
      text: DateTime.now().toString().split(' ')[0],
    );
    _gedungController = TextEditingController();
    _portController = TextEditingController();
    _locationController = TextEditingController();
    _coordinateController = TextEditingController();
    _generateRandomColors();
    if (widget.dbId != null) {
      _loadLocalRecord();
    }
  }

  void _generateRandomColors() {
    if (widget.scrapedHistory == null) return;

    final List<Color> palette = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.amber,
      Colors.pink,
    ];
    palette.shuffle();

    _randomColors = List.generate(widget.scrapedHistory!.length, (index) {
      if (index == 0) return Colors.red; // Latest location is always Red
      return palette[index %
          palette.length]; // Cycle through shuffled palette for others
    });
  }

  @override
  void dispose() {
    _namaController.dispose();
    _tanggalController.dispose();
    _gedungController.dispose();
    _portController.dispose();
    _locationController.dispose();
    _coordinateController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalRecord() async {
    final local = await databaseService.getPerangkatById(widget.dbId!);
    if (local == null || !mounted) return;

    setState(() {
      _namaController.text = local.nama;
      _tanggalController.text = local.tanggal;
      _gedungController.text = local.gedung;
      _portController.text = local.port.toString();
      _locationController.text = local.location;
      _coordinateController.text = local.coordinate;
    });
  }

  // --- LOGIC HELPERS ---

  Color _parseColor(String? colorName) {
    switch (colorName?.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.yellow;
      case 'orange':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  // --- SCRAPED DATA WIDGETS ---

  Widget _buildScrapedMap() {
    if (widget.scrapedMapUrl == null || widget.scrapedMapUrl!.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(17),
        ),
        child: const Center(child: Text("Denah Lokasi Tidak Tersedia")),
      );
    }

    var currentPoint =
        (widget.scrapedHistory != null && widget.scrapedHistory!.isNotEmpty)
        ? widget.scrapedHistory![selectedHistoryIndex]
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(17),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 420),
        width: double.infinity,
        color: Colors.white,
        // We removed IntrinsicHeight and LayoutBuilder from this level
        child: Stack(
          children: [
            // 1. The Image: It will dictate the height of the Stack
            Image.network(
              _getDeviceUrl(widget.scrapedMapUrl!),
              width: double.infinity,
              fit: BoxFit.fitWidth,
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                height: 200,
                child: Center(child: Text("Gagal memuat denah")),
              ),
            ),

            // 2. The Dot Layer: Positioned.fill makes this layer
            // exactly the same size as the Image above.
            if (currentPoint != null)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, imgConstraints) {
                    List<String> coords = (currentPoint['location'] ?? "0,0")
                        .split(',');
                    double dotX = 0;
                    double dotY = 0;

                    if (coords.length == 2) {
                      // Coordinates are calculated based on the Image's actual rendered size
                      dotX =
                          (double.tryParse(coords[0].trim()) ?? 0) /
                          100 *
                          imgConstraints.maxWidth;
                      dotY =
                          (double.tryParse(coords[1].trim()) ?? 0) /
                          100 *
                          imgConstraints.maxHeight;
                    }

                    return Stack(
                      children: [
                        Positioned(
                          left: dotX - 8,
                          top: dotY - 8,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: _randomColors.isNotEmpty
                                  ? _randomColors[selectedHistoryIndex]
                                  : Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTable() {
    if (widget.scrapedHistory == null || widget.scrapedHistory!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(15),
        child: Text("Tidak ada riwayat server."),
      );
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(0.8), // Smaller width for the color dot
        1: FlexColumnWidth(1.5),
        2: FlexColumnWidth(1.5),
        3: FlexColumnWidth(2),
      },
      border: TableBorder.symmetric(
        inside: const BorderSide(color: Colors.white30, width: 1),
      ),
      children: [
        const TableRow(
          children: [
            Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                "Dot",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                "Gedung",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                "Lokasi",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                "Tanggal",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        ...widget.scrapedHistory!.asMap().entries.map((entry) {
          int idx = entry.key;
          var item = entry.value;
          bool isSelected = selectedHistoryIndex == idx;

          return TableRow(
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white10
                  : Colors.transparent, // Highlight selected row
            ),
            children: [
              _buildTableCell(
                idx,
                Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color:
                          _randomColors[idx], // Red for index 0, random for others
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  ),
                ),
              ),
              _buildTableCell(
                idx,
                Text(
                  item['building'] ?? "-",
                  style: const TextStyle(fontSize: 10),
                ),
              ),
              _buildTableCell(
                idx,
                Text(
                  item['location'] ?? "-",
                  style: const TextStyle(fontSize: 10),
                ),
              ),
              _buildTableCell(
                idx,
                Text(item['date'] ?? "-", style: const TextStyle(fontSize: 9)),
              ),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTableCell(int index, Widget child) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => selectedHistoryIndex = index),
      child: Padding(padding: const EdgeInsets.all(8), child: child),
    );
  }

  // --- MAIN UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 219, 229, 255),
      body: Stack(
        children: [
          ListView(
            children: [
              Stack(
                children: [
                  gradientBG(context),
                  perangkatViewer(context),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 90,
                      left: 40,
                      right: 40,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Detail Perangkat",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(132, 184, 202, 255),
                            border: Border.all(color: Colors.white, width: 3.0),
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: detailPerangkat(),
                        ),
                        const SizedBox(height: 20),
                        const Center(
                          child: Text(
                            "Lokasi Perangkat",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildScrapedMap(),
                        const SizedBox(height: 20),
                        const Text(
                          "Riwayat Lokasi",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(113, 122, 151, 255),
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: _buildHistoryTable(),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Catatan Lokal",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(113, 122, 151, 255),
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: !isEdit
                              ? listDataPerangkat()
                              : buildEditFields(),
                        ),
                        const SizedBox(height: 120), // Space for bottom buttons
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Navigation & Action Buttons
          Positioned(
            top: 30,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => BaseHome()),
              ),
              child: Container(
                height: 55,
                width: 110,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 184, 202, 255),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: SvgPicture.asset(
                  "asset/icons/Arrow - Left 2.svg",
                  width: 60,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 15,
            right: 20,
            left: 20,
            child: !isEdit ? buildViewModeButtons() : buildEditModeButtons(),
          ),
        ],
      ),
    );
  }

  // --- COMPONENT HELPERS ---

  Widget perangkatViewer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40, right: 10),
      child: Align(
        alignment: Alignment.topRight,
        child: Container(
          // Constrain the entire group so it doesn't push other widgets
          width: 160,
          child: Column(
            mainAxisSize:
                MainAxisSize.min, // Essential: Stop vertical stretching
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // --- THE NAMECARD (The Blue Tab) ---
              Container(
                alignment: Alignment.center,
                width: 160,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFB8CAFF),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                ),
                child: Text(
                  // Show device identifier as the primary name; fallback to local name or scraped name.
                  widget.idPerangkat != null
                      ? widget.idPerangkat.toString()
                      : (_namaController.text.isEmpty
                            ? (widget.initialName ?? "-")
                            : _namaController.text),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),

              // --- THE 3D VIEWER ---
            ],
          ),
        ),
      ),
    );
  }

  Widget detailPerangkat() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("Status: ", style: const TextStyle(fontSize: 16)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                // Check if the trimmed, lowercase status is 'active'
                color: widget.status?.trim().toLowerCase() == 'active'
                    ? Colors.green
                    : Colors.red,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "${widget.status != null && widget.status!.isNotEmpty ? widget.status : '-'}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors
                      .white, // White text stands out better against red/green
                ),
              ),
            ),
          ],
        ),

        Text(
          "Model: ${_namaController.text.isNotEmpty ? _namaController.text : (widget.initialName ?? '-')}",
          style: TextStyle(fontSize: 16),
        ),
        Text(
          "Source: ${widget.originalUrl ?? '-'}",
          style: const TextStyle(fontSize: 10, color: Colors.black54),
        ),
        SizedBox(height: 20),
        Container(
          width: 290,
          height: 160,
          decoration: const BoxDecoration(
            color: Color.fromARGB(255, 165, 159, 159),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(15),
              bottomRight: Radius.circular(15),
            ),
          ),
          child: widget.scrapedModelUrl != null
              ? ModelViewer(
                  backgroundColor: const Color.fromARGB(0, 7, 3, 255),
                  src: _getDeviceUrl(widget.scrapedModelUrl!),
                  alt: "3D Model",
                  autoRotate: true,
                  cameraControls: true,
                  ar: false,
                  loading: Loading.eager,
                )
              : const Icon(Icons.devices, size: 50, color: Colors.grey),
        ),
      ],
    );
  }

  Widget buildEditFields() {
    return Column(
      children: [
        TextField(
          controller: _namaController,
          decoration: const InputDecoration(labelText: "Nama Perangkat"),
        ),
        TextField(
          controller: _tanggalController,
          decoration: const InputDecoration(labelText: "Tanggal"),
        ),
        TextField(
          controller: _gedungController,
          decoration: const InputDecoration(labelText: "Gedung"),
        ),
        TextField(
          controller: _portController,
          decoration: const InputDecoration(labelText: "Port"),
          keyboardType: TextInputType.number,
        ),
        TextField(
          controller: _locationController,
          decoration: const InputDecoration(labelText: "Lokasi Catatan"),
        ),
        TextField(
          controller: _coordinateController,
          decoration: const InputDecoration(labelText: "Koordinat Catatan"),
        ),
      ],
    );
  }

  Widget buildViewModeButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        actionButton("Web", const Color.fromARGB(255, 7, 226, 255), () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WebView(
                pageLink: widget.originalUrl ?? "",
                id: widget.idPerangkat,
                status: false,
              ),
            ),
          );
        }),
        const SizedBox(width: 10),
        actionButton("Edit", Colors.amber, () => setState(() => isEdit = true)),
      ],
    );
  }

  Widget buildEditModeButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        actionButton(
          "Batal",
          Colors.redAccent,
          () => setState(() => isEdit = false),
        ),
        const SizedBox(width: 10),
        actionButton("Simpan", const Color.fromARGB(255, 7, 255, 61), () async {
          if (widget.dbId != null) {
            // --- UPDATE LOGIC ---
            PerangkatModel updatedData = PerangkatModel(
              id: widget.dbId!,
              nama: _namaController.text,
              tanggal: _tanggalController.text,
              gedung: _gedungController.text,
              port: int.tryParse(_portController.text) ?? 0,
              url: widget.originalUrl ?? "",
              location: _locationController.text,
              coordinate: _coordinateController.text,
            );

            await databaseService.updatePerangkat(updatedData);
          } else {
            // --- ADD LOGIC ---
            await databaseService.addPerangkat(
              _namaController.text,
              _tanggalController.text,
              _gedungController.text,
              _portController.text,
              widget.originalUrl ?? "",
              _locationController.text,
              _coordinateController.text,
            );
          }

          setState(() => isEdit = false);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.dbId != null ? "Data Diperbarui" : "Data Disimpan",
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget actionButton(String title, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 55,
        width: 100,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget gradientBG(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height / 1.2,
      padding: const EdgeInsets.only(top: 80, left: 10, right: 10),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.center,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF94AFFF), Color(0xFFDBE5FF)],
          ),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(17)),
        ),
      ),
    );
  }

  Widget listDataPerangkat() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Nama: ${_namaController.text}"),
        Text("Gedung: ${_gedungController.text}"),
        Text("Tanggal: ${_tanggalController.text}"),
        Text("Port: ${_portController.text}"),
        Text(
          "Lokasi Catatan: ${_locationController.text.isEmpty ? '-' : _locationController.text}",
        ),
        Text(
          "Koordinat Catatan: ${_coordinateController.text.isEmpty ? '-' : _coordinateController.text}",
        ),
      ],
    );
  }
}
