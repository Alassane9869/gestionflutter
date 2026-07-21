import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/theme/app_theme.dart';

class CachedTileProvider extends TileProvider {
  CachedTileProvider();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      headers: const {
        'User-Agent': 'DanayaPlusApp/1.0 (com.danaya.plus; contact@danayaplus.com)',
      },
    );
  }
}

// ══════════════════════════════════════════════
// MAP STYLE DEFINITIONS (7 Styles)
// ══════════════════════════════════════════════

class MapStyle {
  final String id;
  final String label;
  final IconData icon;
  final String urlTemplate;
  final List<String> subdomains;
  final ColorFilter? colorFilter;

  const MapStyle({
    required this.id,
    required this.label,
    required this.icon,
    required this.urlTemplate,
    this.subdomains = const ['mt0', 'mt1', 'mt2', 'mt3'],
    this.colorFilter,
  });
}

final List<MapStyle> kMapStyles = [
  // 1. Standard (Google Maps coloré)
  const MapStyle(
    id: 'standard',
    label: 'Standard',
    icon: FluentIcons.map_24_regular,
    urlTemplate: 'https://{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
  ),
  // 2. Satellite (Esri World Imagery HD)
  const MapStyle(
    id: 'satellite',
    label: 'Satellite',
    icon: FluentIcons.earth_24_regular,
    urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    subdomains: [],
  ),
  // 3. Hybride (Google Satellite + Routes)
  const MapStyle(
    id: 'hybrid',
    label: 'Hybride',
    icon: FluentIcons.globe_24_regular,
    urlTemplate: 'https://{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
  ),
  // 4. Terrain (Google Terrain)
  const MapStyle(
    id: 'terrain',
    label: 'Terrain',
    icon: FluentIcons.mountain_trail_24_regular,
    urlTemplate: 'https://{s}.google.com/vt/lyrs=p&x={x}&y={y}&z={z}',
  ),
  // 5. Nuit Tesla (Hybride + filtre bleu nuit cyberpunk)
  MapStyle(
    id: 'tesla_night',
    label: 'Nuit Tesla',
    icon: FluentIcons.vehicle_car_24_regular,
    urlTemplate: 'https://{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
    colorFilter: const ColorFilter.matrix([
      0.2, 0.0, 0.0, 0.0, -30.0,
      0.0, 0.25, 0.0, 0.0, -20.0,
      0.0, 0.0, 0.55, 0.0, 40.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ]),
  ),
  // 6. Dark Elegant (CartoDB Dark Matter)
  const MapStyle(
    id: 'dark_elegant',
    label: 'Dark Élégant',
    icon: FluentIcons.dark_theme_24_regular,
    urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png',
    subdomains: ['a', 'b', 'c', 'd'],
  ),
  // 7. Voyager (CartoDB) - Clair et professionnel
  const MapStyle(
    id: 'voyager',
    label: 'Voyager',
    icon: FluentIcons.navigation_24_regular,
    urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
    subdomains: ['a', 'b', 'c', 'd'],
  ),
];

// ══════════════════════════════════════════════
// ADDRESS ROUTE MAP WIDGET
// ══════════════════════════════════════════════

class AddressRouteMap extends StatefulWidget {
  final String originAddress;
  final String destinationAddress;
  final String originLabel;
  final String destinationLabel;
  final Function(LatLng origin, LatLng destination, double distance, double duration)? onRouteLoaded;

  const AddressRouteMap({
    super.key,
    required this.originAddress,
    required this.destinationAddress,
    this.originLabel = 'Boutique',
    this.destinationLabel = 'Destination',
    this.onRouteLoaded,
  });

  @override
  State<AddressRouteMap> createState() => _AddressRouteMapState();
}

class _AddressRouteMapState extends State<AddressRouteMap> {
  bool _isLoading = true;
  String? _errorMessage;
  LatLng? _origin;
  LatLng? _destination;
  List<LatLng> _routePoints = [];
  double _distanceKm = 0;
  double _durationMin = 0;
  int _selectedStyleIndex = 0;
  bool _showStylePicker = false;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  @override
  void didUpdateWidget(AddressRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.originAddress != widget.originAddress || 
        oldWidget.destinationAddress != widget.destinationAddress) {
      _loadRoute();
    }
  }

  Future<void> _loadRoute() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _origin = await _geocode(widget.originAddress);
      if (_origin == null) throw "Adresse de départ introuvable ou incomplète";

      _destination = await _geocode(widget.destinationAddress);
      if (_destination == null) throw "Adresse de destination introuvable ou incomplète";

      await _fetchRoute();
      
      if (_origin != null && _destination != null && widget.onRouteLoaded != null) {
        widget.onRouteLoaded!(_origin!, _destination!, _distanceKm, _durationMin);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<LatLng?> _geocode(String address) async {
    if (address.trim().isEmpty) return null;
    final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(address)}&format=json&limit=1');
    final res = await http.get(url, headers: {
      'User-Agent': 'DanayaPlusApp/1.0 (com.danaya.plus; contact@danayaplus.com)',
    });
    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      if (data.isNotEmpty) {
        return LatLng(
          double.parse(data.first['lat'] as String),
          double.parse(data.first['lon'] as String),
        );
      }
    }
    return null;
  }

  Future<void> _fetchRoute() async {
    if (_origin == null || _destination == null) return;
    final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/${_origin!.longitude},${_origin!.latitude};${_destination!.longitude},${_destination!.latitude}?overview=full&geometries=geojson');
    final res = await http.get(url);
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
        final route = data['routes'][0];
        _distanceKm = (route['distance'] as num) / 1000.0;
        _durationMin = (route['duration'] as num) / 60.0;
        final coords = route['geometry']['coordinates'] as List;
        _routePoints = coords.map((c) => LatLng(c[1] as double, c[0] as double)).toList();
      }
    }
  }

  void _recenterMap() {
    if (_origin != null && _destination != null) {
      final bounds = LatLngBounds.fromPoints([_origin!, _destination!, ..._routePoints]);
      _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)));
    }
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;

    if (_isLoading) {
      return Container(
        color: isDark ? const Color(0xFF0A0B0F) : const Color(0xFFF7F9FC),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: accent,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "CALCUL DE L'ITINÉRAIRE OSRM",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Géocodage et tracé en cours...",
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        color: isDark ? const Color(0xFF0F1115) : Colors.white,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FluentIcons.location_off_24_regular, size: 48, color: AppTheme.errorClr),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _loadRoute,
                  icon: const Icon(FluentIcons.arrow_clockwise_20_regular, size: 16),
                  label: const Text("Réessayer"),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bounds = LatLngBounds.fromPoints([_origin!, _destination!, ..._routePoints]);
    final currentStyle = kMapStyles[_selectedStyleIndex];
    final isNightStyle = currentStyle.id == 'tesla_night' || currentStyle.id == 'dark_elegant';

    return Stack(
      children: [
        // ──── MAP ────
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
          ),
          children: [
            TileLayer(
              urlTemplate: currentStyle.urlTemplate,
              subdomains: currentStyle.subdomains,
              tileProvider: CachedTileProvider(),
              tileBuilder: currentStyle.colorFilter != null
                  ? (context, tileWidget, tile) {
                      return ColorFiltered(
                        colorFilter: currentStyle.colorFilter!,
                        child: tileWidget,
                      );
                    }
                  : null,
            ),
            // Route glow
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _routePoints,
                  strokeWidth: 10.0,
                  color: isNightStyle
                      ? const Color(0xFF00FFCC).withValues(alpha: 0.25)
                      : accent.withValues(alpha: 0.2),
                ),
                Polyline(
                  points: _routePoints,
                  strokeWidth: 5.0,
                  color: isNightStyle
                      ? const Color(0xFF00FFCC).withValues(alpha: 0.5)
                      : accent.withValues(alpha: 0.4),
                ),
                Polyline(
                  points: _routePoints,
                  strokeWidth: 3.0,
                  color: isNightStyle ? const Color(0xFF00FFCC) : accent,
                ),
              ],
            ),
            // Markers
            MarkerLayer(
              markers: [
                Marker(
                  point: _origin!,
                  width: 60,
                  height: 60,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _PulseRing(color: Colors.blue),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.5),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(FluentIcons.building_retail_24_regular, color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                ),
                Marker(
                  point: _destination!,
                  width: 60,
                  height: 60,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _PulseRing(color: const Color(0xFFEF4444)),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(FluentIcons.location_24_filled, color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        // ──── GLASSMORPHISM TELEMETRY HUD (top-right) ────
        Positioned(
          top: 16,
          right: 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHudMetric(
                      icon: FluentIcons.vehicle_car_24_regular,
                      iconColor: const Color(0xFF3B82F6),
                      label: "DISTANCE",
                      value: _distanceKm >= 1
                          ? "${_distanceKm.toStringAsFixed(1)} KM"
                          : "${(_distanceKm * 1000).toStringAsFixed(0)} M",
                      isDark: isDark,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Divider(
                        height: 1,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                      ),
                    ),
                    _buildHudMetric(
                      icon: FluentIcons.timer_24_regular,
                      iconColor: const Color(0xFFF59E0B),
                      label: "DURÉE ESTIMÉE",
                      value: _durationMin >= 60
                          ? "${(_durationMin / 60).toStringAsFixed(0)}h ${(_durationMin % 60).toStringAsFixed(0)}min"
                          : "~${_durationMin.toStringAsFixed(0)} MIN",
                      isDark: isDark,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Divider(
                        height: 1,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                      ),
                    ),
                    _buildHudMetric(
                      icon: FluentIcons.top_speed_24_regular,
                      iconColor: const Color(0xFF10B981),
                      label: "VIT. MOYENNE",
                      value: _durationMin > 0
                          ? "${(_distanceKm / (_durationMin / 60)).toStringAsFixed(0)} KM/H"
                          : "—",
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ──── ORIGIN / DESTINATION LABELS (top-left) ────
        Positioned(
          top: 16,
          left: 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxWidth: 260),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLocationRow(
                      color: const Color(0xFF3B82F6),
                      label: widget.originLabel,
                      address: widget.originAddress,
                      isDark: isDark,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 9),
                      child: Container(
                        width: 2,
                        height: 16,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color(0xFF3B82F6), const Color(0xFFEF4444)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                    _buildLocationRow(
                      color: const Color(0xFFEF4444),
                      label: widget.destinationLabel,
                      address: widget.destinationAddress,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ──── NAVIGATION CONTROLS (right side) ────
        Positioned(
          right: 16,
          bottom: 90,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildNavButton(FluentIcons.add_24_regular, "Zoom +", _zoomIn, isDark),
                    Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06)),
                    _buildNavButton(FluentIcons.subtract_24_regular, "Zoom -", _zoomOut, isDark),
                    Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06)),
                    _buildNavButton(FluentIcons.my_location_24_regular, "Recentrer", _recenterMap, isDark),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ──── MAP STYLE SELECTOR (bottom) ────
        Positioned(
          bottom: 16,
          left: 16,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Expanded style picker
              if (_showStylePicker)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                        ),
                      ),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: List.generate(kMapStyles.length, (i) {
                          final style = kMapStyles[i];
                          final isSelected = i == _selectedStyleIndex;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedStyleIndex = i;
                                _showStylePicker = false;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? accent.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? accent.withValues(alpha: 0.5)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(style.icon, size: 16, color: isSelected ? accent : (isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                                  const SizedBox(width: 6),
                                  Text(
                                    style.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? accent : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),

              // Toggle button
              InkWell(
                onTap: () => setState(() => _showStylePicker = !_showStylePicker),
                borderRadius: BorderRadius.circular(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(currentStyle.icon, size: 16, color: accent),
                          const SizedBox(width: 8),
                          Text(
                            currentStyle.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _showStylePicker ? FluentIcons.chevron_down_16_regular : FluentIcons.chevron_up_16_regular,
                            size: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──── HUD Metric Row ────
  Widget _buildHudMetric({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ──── Location Row ────
  Widget _buildLocationRow({
    required Color color,
    required String label,
    required String address,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                address,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──── Nav Button ────
  Widget _buildNavButton(IconData icon, String tooltip, VoidCallback onTap, bool isDark) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 18, color: isDark ? Colors.white70 : Colors.black54),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// PULSE RING ANIMATION
// ══════════════════════════════════════════════

class _PulseRing extends StatefulWidget {
  final Color color;
  const _PulseRing({required this.color});

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _animation = Tween<double>(begin: 0.4, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 48 * _animation.value,
          height: 48 * _animation.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.color.withValues(alpha: 1.0 - _controller.value),
              width: 1.5,
            ),
          ),
        );
      },
    );
  }
}
