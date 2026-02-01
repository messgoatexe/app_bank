# Guide d'Intégration des Nouvelles Fonctionnalités

Ce document explique comment intégrer les trois nouvelles fonctionnalités majeures dans votre application Flutter de gestion de budget.

## 📋 Fonctionnalités Implémentées

1. ✅ **Import/Export CSV/Excel/PDF**
   - Export des transactions en CSV, Excel et PDF
   - Import des transactions depuis CSV et Excel
   - Génération de rapports formatés

2. ✅ **Notifications et Rappels**
   - Alertes de dépenses dépassant les limites
   - Rappels quotidiens
   - Avertissements de solde faible

3. ✅ **Mode Offline et Synchronisation MySQL**
   - File d'attente de synchronisation locale
   - Sync automatique lors de la connexion
   - Gestion des entités (transactions, comptes, catégories)

---

## 🛠️ Installation et Configuration

### Étape 1: Mettre à jour les dépendances

Les dépendances suivantes ont déjà été ajoutées à `pubspec.yaml`:

```yaml
# CSV/Excel/PDF Export
csv: ^6.0.0
excel: ^4.0.3
pdf: ^3.10.5
printing: ^5.11.0

# File handling
file_picker: ^5.3.4
path_provider: ^2.0.15
permission_handler: ^11.4.4

# Notifications
flutter_local_notifications: ^16.3.1
timezone: ^0.9.2

# Offline sync
connectivity_plus: ^5.0.2
workmanager: ^0.5.1
```

Exécutez:
```bash
flutter pub get
```

### Étape 2: Initialiser les services dans main.dart

Modifiez votre `main.dart` pour initialiser les services:

```dart
import 'services/notification_service.dart';
import 'services/offline_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ... vos initialisations existantes ...
  
  // Initialiser les notifications
  await NotificationService.instance.initialize();
  
  // Initialiser la synchronisation offline
  await OfflineSyncService.instance.initialize();
  
  runApp(const MyApp());
}
```

### Étape 3: Configurer les permissions Android

Dans `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Permissions pour les notifications -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- Permissions pour les fichiers -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

<!-- Permissions pour la connectivité -->
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### Étape 4: Configurer les permissions iOS

Dans `ios/Runner/Info.plist`:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Vérification de la connexion réseau</string>
<key>NSBonjourServiceTypes</key>
<array>
  <string>_services._dns-sd._udp</string>
</array>
```

---

## 📱 Utilisation des Fonctionnalités

### 1. Import/Export de Transactions

#### Exporter les transactions

```dart
import 'services/export_service.dart';

// Exporter en CSV
final csvPath = await ExportService.instance.exportToCSV(transactions);

// Exporter en Excel
final excelPath = await ExportService.instance.exportToExcel(transactions);

// Exporter en PDF
final pdfPath = await ExportService.instance.exportToPDF(
  transactions,
  userName: 'Jean Dupont'
);
```

#### Importer les transactions

```dart
import 'services/import_service.dart';
import 'dart:io';

// Importer depuis CSV
final transactions = await ImportService.instance.importFromCSV(
  File('/path/to/file.csv'),
  userId: '123',
  accountId: '456',
);

// Importer depuis Excel
final transactions = await ImportService.instance.importFromExcel(
  File('/path/to/file.xlsx'),
  userId: '123',
  accountId: '456',
);
```

#### Utiliser le widget d'import/export

Ajoutez le widget à votre écran de transactions:

```dart
import 'widgets/import_export_widget.dart';

class TransactionsListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ImportExportWidget(
          transactions: transactions,
          userName: 'Jean Dupont',
          onTransactionsImported: () {
            // Recharger les transactions
            context.read<TransactionsProvider>().loadTransactions();
          },
        ),
        // ... rest of your UI
      ],
    );
  }
}
```

---

### 2. Notifications et Rappels

#### Initialiser les reminders

```dart
import 'providers/reminders_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser les reminders
  await RemindersProvider.instance.initialize(userId);
  
  runApp(const MyApp());
}
```

#### Créer un rappel de dépense

```dart
final reminder = await RemindersProvider.instance.createReminder(
  userId: '123',
  categoryId: 'food_456',
  categoryName: 'Alimentation',
  dailyLimit: 20.0,
  weeklyLimit: 100.0,
  monthlyLimit: 400.0,
  enableNotifications: true,
  alertThreshold: 0.8, // Alerte à 80% du budget
);
```

#### Envoyer une notification de dépasse

```dart
await NotificationService.instance.notifyExpenseAlert(
  categoryName: 'Alimentation',
  amount: 85.00,
  limit: 100.00,
);
```

#### Programmer un rappel quotidien

```dart
await NotificationService.instance.scheduleRecurringNotification(
  id: 100,
  title: 'Rappel quotidien',
  body: 'N\'oubliez pas de vérifier vos dépenses',
  firstScheduledDateTime: DateTime.now().add(Duration(days: 1)),
);
```

---

### 3. Mode Offline et Synchronisation

#### Initialiser le service de sync

```dart
import 'services/offline_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await OfflineSyncService.instance.initialize();
  
  runApp(const MyApp());
}
```

#### Enregistrer une opération hors ligne

```dart
// Enregistrer une nouvelle transaction pour sync
await OfflineSyncService.instance.recordTransaction(
  transaction: transactionModel,
  action: 'create',
);

// Enregistrer une modification de compte
await OfflineSyncService.instance.recordAccount(
  account: accountModel,
  action: 'update',
);
```

#### Synchroniser quand la connexion est rétablie

```dart
// La synchronisation se fait automatiquement quand la connexion revient
// Mais vous pouvez aussi forcer une sync manuelle:

final success = await OfflineSyncService.instance.syncAll(force: true);

if (success) {
  print('Synchronisation réussie!');
} else {
  print('Erreur lors de la synchronisation');
}
```

#### Vérifier le statut de sync

```dart
final syncStatus = OfflineSyncService.instance.getSyncStatus();
print('En ligne: ${syncStatus['isOnline']}');
print('En cours de sync: ${syncStatus['isSyncing']}');

// Obtenir le nombre de changements en attente
final pendingCount = await OfflineSyncService.instance.getPendingSyncCount();
print('$pendingCount changements en attente');
```

#### Afficher le statut sync dans l'UI

```dart
Consumer<OfflineSyncProvider>(
  builder: (context, syncProvider, _) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          color: syncProvider.isOnline ? Colors.green[100] : Colors.red[100],
          child: Text(
            syncProvider.isOnline
                ? '✅ En ligne'
                : '📵 Hors ligne',
            style: TextStyle(
              color: syncProvider.isOnline ? Colors.green[900] : Colors.red[900],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (syncProvider.isSyncing)
          LinearProgressIndicator(),
      ],
    );
  },
)
```

---

## 🗂️ Structure des Fichiers Créés

```
lib/
├── services/
│   ├── export_service.dart          # Export CSV/Excel/PDF
│   ├── import_service.dart          # Import CSV/Excel
│   ├── notification_service.dart    # Gestion des notifications
│   └── offline_sync_service.dart    # Sync offline/online
├── providers/
│   └── reminders_provider.dart      # Gestion des rappels
└── widgets/
    └── import_export_widget.dart    # UI pour import/export
```

---

## 🔄 Flux de Synchronisation Offline

1. **Mode Offline Détecté**
   - L'app continue à fonctionner normalement
   - Les opérations sont enregistrées localement

2. **Enregistrement Local**
   - Chaque opération est ajoutée à `sync_queue` dans SQLite
   - Chaque enregistrement contient: action, entité, données

3. **Mode Online Rétabli**
   - La détection de connexion déclenche automatiquement la sync
   - Les changements en attente sont envoyés au serveur MySQL

4. **Résolution de Conflits**
   - Les données locales ont la priorité
   - Les timestamps permettent de résoudre les conflits

---

## 📊 Format d'Import/Export

### CSV
```
ID,Date,Type,Category,Amount,Description
e5b7a3f1-2c9d-4e1f-9a8b-c6d2e1f5a9c7,15/01/2026 14:30,Dépense,Alimentation,25.50,Courses au marché
```

### Excel
Mêmes colonnes que CSV mais dans un classeur Excel avec mise en forme

### PDF
Rapport formaté avec:
- En-tête avec nom utilisateur et date de génération
- Transactions groupées par jour
- Total par jour
- Total général

---

## ⚙️ Configuration Avancée

### Seuil d'alerte personnalisé

```dart
// Définir l'alerte à 75% au lieu de 80%
final reminder = await RemindersProvider.instance.createReminder(
  userId: '123',
  categoryId: 'food_456',
  categoryName: 'Alimentation',
  monthlyLimit: 500.0,
  alertThreshold: 0.75,
);
```

### Notification personnalisée

```dart
// Envoyer une notification custom
await NotificationService.instance.showNotification(
  id: 9999,
  title: 'Titre personnalisé',
  body: 'Message personnalisé',
  payload: 'custom_action',
);
```

### Forcer la synchronisation à intervalles réguliers

```dart
// Avec workmanager pour les tâches en arrière-plan
// À implémenter selon vos besoins
```

---

## 🧪 Tests

### Tester l'export

```dart
test('Export CSV', () async {
  final transactions = [/* ... */];
  final path = await ExportService.instance.exportToCSV(transactions);
  expect(File(path).existsSync(), true);
});
```

### Tester l'import

```dart
test('Import CSV', () async {
  final file = File('test_data.csv');
  final transactions = await ImportService.instance.importFromCSV(
    file,
    'user123',
    'account456',
  );
  expect(transactions.isNotEmpty, true);
});
```

---

## 🐛 Dépannage

### "Notification not showing"
- Vérifier les permissions dans AndroidManifest.xml
- Sur Android 13+, demander la permission POST_NOTIFICATIONS

### "Import fails with encoding error"
- S'assurer que le fichier CSV est encodé en UTF-8
- Vérifier le séparateur (virgule vs point-virgule)

### "Sync queue keeps growing"
- Vérifier la connexion réseau
- Vérifier la disponibilité du serveur MySQL
- Consulter les logs de sync dans la console

---

## 📝 Prochaines Étapes

1. **Intégrer le widget ImportExportWidget** dans votre écran de transactions
2. **Initialiser les services** dans main.dart
3. **Tester chaque fonctionnalité** en mode offline et online
4. **Configurer les permissions** selon vos besoins
5. **Personnaliser les rappels** pour vos catégories
6. **Implémenter la sync MySQL** complète si nécessaire

---

## 📞 Support

Pour toute question ou problème, consultez:
- Documentation Flutter: https://flutter.dev/docs
- Documentation des packages utilisés sur pub.dev
- Logs de l'application pour les erreurs détaillées
