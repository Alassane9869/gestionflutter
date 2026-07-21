import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:danaya_plus/core/widgets/address_route_map.dart'; // For CachedTileProvider

class AddressAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final void Function(String)? onChanged;

  const AddressAutocompleteField({
    super.key,
    required this.controller,
    this.label = "ADRESSE",
    this.hint = "Rechercher une adresse...",
    this.onChanged,
  });

  @override
  State<AddressAutocompleteField> createState() => _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  Timer? _debounce;
  List<String> _suggestions = [];
  bool _isLoading = false;

  Future<void> _fetchSuggestions(String query) async {
    if (query.trim().length < 3) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Restrict autocomplete results strictly to West African countries using FCFA to avoid noise from Europe
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=8&addressdetails=1&countrycodes=ml,sn,ci,bf,ne,tg,bj');
      final response = await http.get(url, headers: {
        'User-Agent': 'DanayaPlusApp/1.0 (com.danaya.plus; contact@danayaplus.com)'
      });

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          _suggestions = data.map<String>((item) => item['display_name'] as String).toList();
        });
      }
    } catch (e) {
      // Ignorer les erreurs réseau pour l'autocomplétion
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldWidth = constraints.maxWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  widget.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: widget.controller.text),
              optionsBuilder: (TextEditingValue textEditingValue) async {
                final query = textEditingValue.text;
                if (query.length < 3) return const Iterable<String>.empty();
                
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                
                final completer = Completer<Iterable<String>>();
                _debounce = Timer(const Duration(milliseconds: 500), () async {
                  await _fetchSuggestions(query);
                  completer.complete(_suggestions);
                });

                return completer.future;
              },
              onSelected: (String selection) {
                widget.controller.text = selection;
                if (widget.onChanged != null) widget.onChanged!(selection);
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                // Sync outer controller with inner controller
                textEditingController.addListener(() {
                  if (widget.controller.text != textEditingController.text) {
                    widget.controller.text = textEditingController.text;
                    if (widget.onChanged != null) widget.onChanged!(textEditingController.text);
                  }
                });

                return TextFormField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                    prefixIcon: Icon(FluentIcons.location_24_regular, size: 20, color: theme.colorScheme.primary),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        IconButton(
                          tooltip: "Sélectionner sur la carte (Vision Satellite disponible)",
                          icon: Icon(FluentIcons.location_24_regular, color: theme.colorScheme.primary),
                          onPressed: () async {
                            LatLng initial = const LatLng(12.6392, -8.0029); // Bamako par défaut
                            if (textEditingController.text.trim().isNotEmpty) {
                              try {
                                final url = Uri.parse(
                                    'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(textEditingController.text)}&format=json&limit=1');
                                final res = await http.get(url, headers: {
                                  'User-Agent': 'DanayaPlusApp/1.0 (com.danaya.plus; contact@danayaplus.com)'
                                });
                                if (res.statusCode == 200) {
                                  final List data = json.decode(res.body);
                                  if (data.isNotEmpty) {
                                    initial = LatLng(
                                      double.parse(data.first['lat'] as String),
                                      double.parse(data.first['lon'] as String),
                                    );
                                  }
                                }
                              } catch (_) {}
                            }

                            if (!context.mounted) return;
                            final selectedAddress = await showDialog<String>(
                              context: context,
                              builder: (context) => MapPickerDialog(initialCenter: initial),
                            );

                            if (selectedAddress != null && selectedAddress.isNotEmpty) {
                              textEditingController.text = selectedAddress;
                              widget.controller.text = selectedAddress;
                              if (widget.onChanged != null) {
                                widget.onChanged!(selectedAddress);
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 1),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    ),
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 12,
                    borderRadius: BorderRadius.circular(16),
                    color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                    child: Container(
                      width: fieldWidth,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          separatorBuilder: (context, index) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade100),
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            return InkWell(
                              onTap: () => onSelected(option),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                                child: Row(
                                  children: [
                                    Icon(FluentIcons.location_20_regular, size: 16, color: theme.colorScheme.primary),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        option,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class MapPickerDialog extends StatefulWidget {
  final LatLng initialCenter;
  const MapPickerDialog({super.key, required this.initialCenter});

  @override
  State<MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<MapPickerDialog> {
  late final MapController _mapController;
  LatLng _currentCenter = const LatLng(12.6392, -8.0029);
  String _address = "Déplacez la carte pour choisir...";
  bool _isGeocoding = false;
  bool _isSatelliteView = false;
  Timer? _geocodeDebounce;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentCenter = widget.initialCenter;
    _triggerReverseGeocode(_currentCenter);
  }

  void _triggerReverseGeocode(LatLng point) {
    if (_geocodeDebounce?.isActive ?? false) _geocodeDebounce!.cancel();
    setState(() {
      _isGeocoding = true;
      _currentCenter = point;
    });
    _geocodeDebounce = Timer(const Duration(milliseconds: 700), () async {
      final addr = await _reverseGeocode(point.latitude, point.longitude);
      if (mounted) {
        setState(() {
          _isGeocoding = false;
          if (addr != null && addr.isNotEmpty) {
            _address = addr;
          } else {
            _address = "${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}";
          }
        });
      }
    });
  }

  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&addressdetails=1');
      final response = await http.get(url, headers: {
        'User-Agent': 'DanayaPlusApp/1.0 (com.danaya.plus; contact@danayaplus.com)'
      });
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _searchAndFly() async {
    final query = _searchCtrl.text.trim();
    if (query.length < 3) return;
    setState(() => _isGeocoding = true);
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1&countrycodes=ml,sn,ci,bf,ne,tg,bj');
      final response = await http.get(url, headers: {
        'User-Agent': 'DanayaPlusApp/1.0 (com.danaya.plus; contact@danayaplus.com)'
      });
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data.first['lat'] as String);
          final lon = double.parse(data.first['lon'] as String);
          final target = LatLng(lat, lon);
          _mapController.move(target, 16);
          _triggerReverseGeocode(target);
        }
      }
    } catch (_) {} finally {
      if (mounted) {
        setState(() => _isGeocoding = false);
      }
    }
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _mapController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 800,
        height: 600,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 24,
              offset: Offset(0, 10),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentCenter,
                  initialZoom: 16,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                  onPositionChanged: (pos, hasGesture) {
                    if (hasGesture) {
                      _triggerReverseGeocode(pos.center);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: _isSatelliteView
                        ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                        : (isDark
                            ? 'https://{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                            : 'https://{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}'),
                    subdomains: _isSatelliteView ? const [] : const ['mt0', 'mt1', 'mt2', 'mt3'],
                    tileProvider: CachedTileProvider(),
                    tileBuilder: (context, tileWidget, tile) {
                      if (isDark && !_isSatelliteView) {
                        return ColorFiltered(
                          colorFilter: const ColorFilter.matrix([
                            0.3, 0.0, 0.0, 0.0, -20.0, 
                            0.0, 0.4, 0.0, 0.0, -10.0, 
                            0.0, 0.0, 0.6, 0.0, 30.0,  
                            0.0, 0.0, 0.0, 1.0, 0.0,   
                          ]),
                          child: tileWidget,
                        );
                      }
                      return tileWidget;
                    },
                  ),
                ],
              ),

              // Central Target Pin (Futuristique Crosshair)
              Center(
                child: IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1)
                          ],
                        ),
                      ),
                      Container(width: 2, height: 16, color: colorScheme.primary),
                      Icon(
                        FluentIcons.location_24_filled,
                        size: 36,
                        color: colorScheme.primary,
                        shadows: const [
                          Shadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3))
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Top Search Panel
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF111318) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(FluentIcons.search_24_regular, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: "Rechercher une ville, quartier ou repère...",
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onSubmitted: (_) => _searchAndFly(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(FluentIcons.arrow_right_24_regular, size: 20),
                        onPressed: _searchAndFly,
                      ),
                    ],
                  ),
                ),
              ),

              // Floating Layer Selector FAB
              Positioned(
                bottom: 120,
                right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'picker_layer_toggle',
                  backgroundColor: isDark ? const Color(0xFF1E2129) : Colors.white,
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onPressed: () {
                    setState(() {
                      _isSatelliteView = !_isSatelliteView;
                    });
                  },
                  child: Icon(
                    _isSatelliteView ? FluentIcons.map_24_regular : FluentIcons.earth_24_regular,
                    size: 20,
                  ),
                ),
              ),

              // Bottom Panel with Geocoded Address Info & Confirm Button
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF111318) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 4))
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  "ADRESSE CIBLÉE",
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                if (_isGeocoding) ...[
                                  const SizedBox(width: 8),
                                  const SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(strokeWidth: 1.5),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _address,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(context, _address);
                        },
                        child: const Text(
                          "CONFIRMER",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
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
}
