# 📱 Guide Rapide - Nouvelles Fonctionnalités

## ✨ Résumé des Implémentations

Trois fonctionnalités majeures ont été implémentées dans votre application:

---

## 1️⃣ Import/Export CSV/Excel/PDF

### Services créés:
- `lib/services/export_service.dart` - Exporte en CSV, Excel et PDF
- `lib/services/import_service.dart` - Importe depuis CSV et Excel
- `lib/widgets/import_export_widget.dart` - Widget UI pour les opérations

### Utilisation rapide:

```dart
// EXPORTER
final csvPath = await ExportService.instance.exportToCSV(transactions);
final excelPath = await ExportService.instance.exportToExcel(transactions);
final pdfPath = await ExportService.instance.exportToPDF(transactions, userName);

// IMPORTER
final txs = await ImportService.instance.importFromCSV(file, userId, accountId);
final txs = await ImportService.instance.importFromExcel(file, userId, accountId);
```

### Format des fichiers:
- **CSV**: Colonnes - ID, Date, Type, Category, Amount, Description
- **Excel**: Même structure que CSV avec mise en forme
- **PDF**: Rapport formaté avec graphiques et totaux

---

## 2️⃣ Notifications et Rappels

### Services créés:
- `lib/services/notification_service.dart` - Gestion des notifications
- `lib/providers/reminders_provider.dart` - Gestion des rappels

### Utilisation rapide:

```dart
// INITIALISER
await NotificationService.instance.initialize();
await RemindersProvider.instance.initialize(userId);

// CRÉER UN RAPPEL
await RemindersProvider.instance.createReminder(
  userId: '123',
  categoryId: 'food',
  categoryName: 'Alimentation',
  monthlyLimit: 500.0,
  alertThreshold: 0.8,  // Alerte à 80%
);

// ENVOYER UNE NOTIFICATION
await NotificationService.instance.notifyExpenseAlert(
  categoryName: 'Alimentation',
  amount: 400.0,
  limit: 500.0,
);

// PROGRAMMER UN RAPPEL
await NotificationService.instance.scheduleRecurringNotification(
  id: 100,
  title: 'Rappel quotidien',
  body: 'Vérifiez vos dépenses',
  firstScheduledDateTime: DateTime.now().add(Duration(hours: 1)),
);
```

### Types de notifications:
- 🚨 **Alerte dépense**: Quand on approche/dépasse la limite
- 📅 **Rappel quotidien**: Récapitulatif des dépenses du jour
- ⚠️ **Avertissement solde**: Quand le solde est trop bas

---

## 3️⃣ Mode Offline et Synchronisation MySQL

### Services créés:
- `lib/services/offline_sync_service.dart` - Gestion du sync offline/online

### Utilisation rapide:

```dart
// INITIALISER
await OfflineSyncService.instance.initialize();

// ENREGISTRER UNE OPÉRATION (offline)
await OfflineSyncService.instance.recordTransaction(
  transaction: txModel,
  action: 'create',
);

// SYNCHRONISER (manuel)
final success = await OfflineSyncService.instance.syncAll(force: true);

// VÉRIFIER LE STATUT
final status = OfflineSyncService.instance.getSyncStatus();
print('Online: ${status['isOnline']}, Syncing: ${status['isSyncing']}');

// COMPTER LES CHANGEMENTS EN ATTENTE
final pending = await OfflineSyncService.instance.getPendingSyncCount();
print('$pending changements en attente');
```

### Fonctionnement:
1. **Offline**: Les opérations sont enregistrées localement
2. **Retour online**: Sync automatique des changements
3. **Conflit**: Les données locales ont la priorité

---

## 🔧 Configuration Requise

### Android (`AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### main.dart
```dart
// Ajouter ces initialisations:
await NotificationService.instance.initialize();
await OfflineSyncService.instance.initialize();
```

### pubspec.yaml
✅ Déjà mise à jour avec toutes les dépendances requises:
- csv, excel, pdf, printing (export/import)
- flutter_local_notifications, timezone (notifications)
- connectivity_plus, file_picker, path_provider (offline)

---

## 📊 Architecture des Fichiers

### Services (logique métier)
```
services/
├── export_service.dart      ← Export CSV/Excel/PDF
├── import_service.dart      ← Import CSV/Excel
├── notification_service.dart ← Notifications
└── offline_sync_service.dart ← Sync offline/online
```

### Providers (état avec ChangeNotifier)
```
providers/
└── reminders_provider.dart  ← Gestion des rappels
```

### Widgets (UI)
```
widgets/
└── import_export_widget.dart ← UI import/export
```

---

## 🎯 Cas d'Usage Courants

### Exporter les transactions du mois
```dart
final txs = await TransactionsService.instance.getByUserId(userId);
final filtered = txs.where((tx) => tx.date.month == DateTime.now().month).toList();
final path = await ExportService.instance.exportToPDF(filtered, userName);
// Fichier disponible dans: Documents/transactions_2026-02-01_143022.pdf
```

### Alerter si le budget alimentaire est dépassé
```dart
// Créer un rappel au démarrage
await RemindersProvider.instance.createReminder(
  userId: userId,
  categoryId: 'alimentation',
  categoryName: 'Alimentation',
  monthlyLimit: 500.0,
);

// Vérifier après chaque transaction
await RemindersProvider.instance.checkCategorySpending(
  userId,
  'alimentation',
  'Alimentation',
  dailySpent: 45.0,
  weeklySpent: 280.0,
  monthlySpent: 450.0,
);
```

### Synchroniser les données quand on repasse en ligne
```dart
// Automatique ! Mais vous pouvez forcer:
if (OfflineSyncService.instance.isOnline) {
  await OfflineSyncService.instance.syncAll(force: true);
  print('Sync réussie!');
}
```

---

## 🧪 Tester les Fonctionnalités

### Test Export
1. Créer quelques transactions
2. Appuyer sur "CSV" → Vérifier le fichier dans Documents
3. Appuyer sur "Excel" → Vérifier le fichier dans Documents
4. Appuyer sur "PDF" → Vérifier le fichier dans Documents

### Test Notifications
1. Créer un rappel pour une catégorie
2. Ajouter une transaction qui approche la limite
3. Vérifier que la notification s'affiche

### Test Offline
1. Activer le mode avion
2. Ajouter une transaction (enregistrée localement)
3. Désactiver le mode avion
4. Vérifier que la transaction est synchronisée

---

## 🆘 Dépannage Rapide

| Problème | Solution |
|----------|----------|
| Export échoue | Vérifier les permissions de fichier |
| Notification ne s'affiche pas | Android 13+? Vérifier `POST_NOTIFICATIONS` |
| Import échoue | Vérifier format CSV (UTF-8, délimiteur virgule) |
| Sync ne marche pas | Vérifier la connexion réseau |
| Erreur "Table not found" | Appeler `initialize()` sur les services |

---

## 📚 Fichiers de Documentation

- `INTEGRATION_GUIDE.md` - Guide complet d'intégration
- `JANUARY_2026_IMPLEMENTATION.md` - Historique des implémentations
- `README.md` - Documentation générale du projet

---

## 🚀 Prochaines Étapes

1. ✅ Dépendances ajoutées
2. ✅ Services créés
3. ✅ Providers créés
4. ✅ main.dart mis à jour
5. ⏳ **À FAIRE**: Ajouter le widget ImportExportWidget à votre écran
6. ⏳ **À FAIRE**: Tester les nouvelles fonctionnalités
7. ⏳ **À FAIRE**: Personnaliser les rappels pour vos catégories

---

**Vous êtes prêt! Commencez par tester les exports/imports! 🎉**
