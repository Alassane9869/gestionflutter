import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';
import 'package:danaya_plus/core/widgets/address_route_map.dart';

class MapViewerDialog extends ConsumerStatefulWidget {
  final String originAddress;
  final String destinationAddress;
  final String originLabel;
  final String destinationLabel;

  const MapViewerDialog({
    super.key,
    required this.originAddress,
    required this.destinationAddress,
    required this.originLabel,
    required this.destinationLabel,
  });

  @override
  ConsumerState<MapViewerDialog> createState() => _MapViewerDialogState();

  static Future<void> show(
    BuildContext context, {
    required String originAddress,
    required String destinationAddress,
    required String originLabel,
    required String destinationLabel,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => MapViewerDialog(
        originAddress: originAddress,
        destinationAddress: destinationAddress,
        originLabel: originLabel,
        destinationLabel: destinationLabel,
      ),
    );
  }
}

class _MapViewerDialogState extends ConsumerState<MapViewerDialog> with SingleTickerProviderStateMixin {
  LatLng? _originCoords;
  LatLng? _destinationCoords;
  double? _distance;
  double? _duration;
  late AnimationController _blinkingController;

  @override
  void initState() {
    super.initState();
    _blinkingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkingController.dispose();
    super.dispose();
  }

  Future<void> _openExternalMap() async {
    final query = Uri.encodeComponent(widget.destinationAddress);
    final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF0F1115) : Colors.white,
      elevation: 20,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.85,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      FluentIcons.map_24_regular,
                      color: accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Visualisation de l'Itinéraire",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Système de géolocalisation et calcul de trajectoire OSRM",
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(FluentIcons.dismiss_24_regular),
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 24,
                  ),
                ],
              ),
            ),

            // Content Panel (Split Screen)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Side panel: details (futuristic HUD)
                  Container(
                    width: 340,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0A0C0E) : Colors.grey.shade50,
                      border: Border(
                        right: BorderSide(
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "DÉTAILS DU TRAJET",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // From address
                        _buildAddressNode(
                          icon: FluentIcons.building_retail_24_regular,
                          iconColor: Colors.blue,
                          title: "POINT DE DÉPART (BOUTIQUE)",
                          label: widget.originLabel,
                          address: widget.originAddress,
                          coords: _originCoords,
                          isDark: isDark,
                        ),

                        // Vertical dots line
                        Padding(
                          padding: const EdgeInsets.only(left: 19, top: 4, bottom: 4),
                          child: Container(
                            width: 2,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),

                        // To address
                        _buildAddressNode(
                          icon: FluentIcons.location_24_regular,
                          iconColor: Colors.red,
                          title: "DESTINATION FINALE",
                          label: widget.destinationLabel,
                          address: widget.destinationAddress,
                          coords: _destinationCoords,
                          isDark: isDark,
                        ),

                        const SizedBox(height: 24),
                        const Divider(color: Colors.transparent, height: 16),

                        // Futuristic Telemetry HUD Section
                        Text(
                          "SYSTÈME DE TÉLÉMÉTRIE",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  AnimatedBuilder(
                                    animation: _blinkingController,
                                    builder: (context, child) {
                                      return Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _originCoords != null 
                                              ? const Color(0xFF00FFCC).withValues(alpha: _blinkingController.value)
                                              : Colors.orange.withValues(alpha: _blinkingController.value),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _originCoords != null ? const Color(0xFF00FFCC) : Colors.orange,
                                              blurRadius: 4,
                                            )
                                          ]
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _originCoords != null ? "GPS : ACTIF ET SYNCHRONISÉ" : "GPS : RECHERCHE DU SIGNAL",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _originCoords != null ? const Color(0xFF00FFCC) : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildHudLine("API ROUTAGE", "OSRM ENGINE V1"),
                              _buildHudLine("MODE DE TRAJET", "PROPULSION TERRESTRE"),
                              if (_distance != null) ...[
                                _buildHudLine("DISTANCE GÉO", "${_distance!.toStringAsFixed(2)} km"),
                                _buildHudLine("DURÉE ESTIMÉE", "${_duration!.toStringAsFixed(0)} minutes"),
                              ],
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Google Maps Button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _openExternalMap,
                            icon: const Icon(FluentIcons.open_24_regular, size: 16),
                            label: const Text(
                              "Ouvrir dans Google Maps",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Large Map Container
                  Expanded(
                    child: AddressRouteMap(
                      originAddress: widget.originAddress,
                      destinationAddress: widget.destinationAddress,
                      originLabel: widget.originLabel,
                      destinationLabel: widget.destinationLabel,
                      onRouteLoaded: (origin, dest, dist, dur) {
                        setState(() {
                          _originCoords = origin;
                          _destinationCoords = dest;
                          _distance = dist;
                          _duration = dur;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHudLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressNode({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String label,
    required String address,
    LatLng? coords,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                  height: 1.3,
                ),
              ),
              if (coords != null) ...[
                const SizedBox(height: 4),
                Text(
                  "[${coords.latitude.toStringAsFixed(4)}° N, ${coords.longitude.toStringAsFixed(4)}° E]",
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF00FFCC),
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
