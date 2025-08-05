import 'package:flutter/material.dart';

class DialogUtils {
  static Future<int?> showDoctorSelectionDialog(
    BuildContext context,
    List<dynamic> doctors,
  ) async {
    return showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pilih Dokter Tujuan'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: doctors.length,
              itemBuilder: (context, index) {
                final doctor = doctors[index];
                return ListTile(
                  title: Text(doctor.name),
                  subtitle: Text(doctor.email),
                  onTap: () {
                    Navigator.of(context).pop(doctor.id);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class SnackbarUtils {
  static void showSnackbar(
    BuildContext context,
    String message, {
    Color? backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }
}
