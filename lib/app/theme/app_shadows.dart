import 'package:flutter/widgets.dart';
import 'package:meu_gestor_financeiro/app/theme/app_colors.dart';

abstract final class AppShadows {
  static const List<BoxShadow> elevated = <BoxShadow>[
    BoxShadow(color: AppColors.shadow, blurRadius: 28, offset: Offset(0, 14)),
  ];

  static const List<BoxShadow> focus = <BoxShadow>[
    BoxShadow(color: Color(0x3D17CFFF), blurRadius: 16, spreadRadius: 1),
  ];
}
