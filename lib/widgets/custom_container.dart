import 'package:flutter/material.dart';

class CustomContainer extends StatelessWidget {
  final Widget content;
  const CustomContainer({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withAlpha(100), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(50),
            spreadRadius: 2,
            blurRadius: 3,
          ),
        ],
      ),
      child: content,
    );
  }
}
