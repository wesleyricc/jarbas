import 'package:flutter/material.dart';

/// Uma barra na parte inferior que mostra o preço total atualizado.
class PriceSummaryBar extends StatelessWidget {
  final double totalPrice;
  
  const PriceSummaryBar({super.key, required this.totalPrice});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Preço Total:',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          Text(
            'R\$ ${totalPrice.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[200],
            ),
          ),
        ],
      ),
    );
  }
}