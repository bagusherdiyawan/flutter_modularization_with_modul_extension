import 'package:flutter/material.dart';

import 'pulsa_dashboard_page.dart';

class PulsaEntryPoint extends StatelessWidget {
  const PulsaEntryPoint({super.key, required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context) => PulsaDashboardPage(storeId: storeId);
}
