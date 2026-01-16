import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart'; // Import o Provider
import 'firebase_options.dart';
import 'providers/rod_builder_provider.dart'; // Import o seu Provider
import 'screens/auth_gate.dart'; // Import o AuthGate
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // O Provider DEVE ser injetado AQUI, antes do MaterialApp
  runApp(
    ChangeNotifierProvider(
      create: (context) => RodBuilderProvider(),
      child: const CustomRodsApp(),
    ),
  );
}

class CustomRodsApp extends StatelessWidget {
  const CustomRodsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jarbas Custom Rods',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'), // Define Português do Brasil
      ],

      themeMode: ThemeMode.dark, // Forçar modo escuro
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blueGrey,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E), // Fundo escuro
        cardColor: const Color(0xFF2C2C2C), // Cor dos cards
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none,
          ),
          fillColor: const Color(0xFF2C2C2C),
          filled: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16.0),
          ),
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.blueGrey[200],
          selectionColor: Colors.blueGrey[600],
          selectionHandleColor: Colors.blueGrey[400],
        ),
      ),
      home: const AuthGate(), // O AuthGate gerencia qual tela mostrar
    );
  }
}