import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

import '../utils/countries.dart';

/// Country flag (SVG from country_flags), or a globe when unknown.
class FlagIcon extends StatelessWidget {
  const FlagIcon({super.key, required this.countryCode, this.width = 30, this.height = 20});

  final String countryCode;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (!isKnownCountry(countryCode)) {
      return SizedBox(
        width: width,
        height: height,
        child: Icon(Icons.public_rounded, size: height, color: Colors.white70),
      );
    }
    return CountryFlag.fromCountryCode(
      countryCode,
      shape: const RoundedRectangle(4),
      width: width,
      height: height,
    );
  }
}
