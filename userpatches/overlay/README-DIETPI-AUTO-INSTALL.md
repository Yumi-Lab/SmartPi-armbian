# DietPi Auto-Install System (100% Offline)

## Concept

Au lieu de copier manuellement les scripts DietPi, cette approche utilise l'**installer officiel DietPi** qui s'exécute automatiquement au premier boot.

## Avantages

✅ **100% Offline** - Le repo DietPi complet est dans l'image
✅ **Vrai DietPi** - Utilise l'installer officiel, pas une copie manuelle
✅ **Automatique** - S'exécute au premier boot sans intervention
✅ **À jour** - Utilise la dernière version de DietPi
✅ **Optimisé** - L'installer supprime les paquets inutiles
✅ **Allégé** - Système vraiment optimisé (~400-500 MB vs 1.5 GB)

## Architecture

### Fichiers créés:

1. **dietpi-auto-install.sh** → Script qui lance l'installer au premier boot
2. **dietpi-auto-install.service** → Service systemd (one-shot)
3. **/opt/dietpi-source/** → Repo DietPi complet (copié dans l'image)

### Workflow:

```
Image Armbian
    ↓
Premier boot
    ↓
dietpi-auto-install.service démarre
    ↓
Lance /opt/dietpi-source/.build/images/dietpi-installer
    ↓
Transforme Armbian en DietPi
    ↓
Redémarre
    ↓
DietPi pur et optimisé ✓
```

## Utilisation

### Option 1: Test manuel (sur votre SmartPi1 actuel)

```bash
# 1. Copier les fichiers
sudo cp /home/pi/dietpi-auto-install.sh /usr/local/bin/
sudo chmod 755 /usr/local/bin/dietpi-auto-install.sh

sudo cp /home/pi/dietpi-auto-install.service /etc/systemd/system/
sudo chmod 644 /etc/systemd/system/dietpi-auto-install.service

# 2. Copier le repo DietPi
sudo cp -r /home/pi/DietPi /opt/dietpi-source

# 3. Activer le service
sudo systemctl enable dietpi-auto-install.service

# 4. Lancer manuellement (ou redémarrer)
sudo systemctl start dietpi-auto-install.service

# 5. Suivre les logs
tail -f /var/log/dietpi-auto-install.log
```

### Option 2: Intégrer dans le workflow

Modifier `actions/prepare-dietpi/action.yml`:

1. Copier le repo DietPi complet dans `/opt/dietpi-source`
2. Installer dietpi-auto-install.sh et .service
3. Activer le service
4. L'installer se lance au premier boot

## Variables d'environnement

Dans `dietpi-auto-install.sh`, ces variables sont définies:

```bash
export HW_MODEL=25                    # Generic Allwinner H3
export DISTRO_TARGET=7                # Debian Bookworm
export WIFI_REQUIRED=1                # WiFi support
export IMAGE_CREATOR='Yumi'
export PREIMAGE_INFO='SmartPi Armbian'
```

## Durée d'installation

- **Préparation image**: ~1-2 minutes (copie du repo)
- **Premier boot**: ~20-30 minutes (installation DietPi)
- **Total**: ~25-35 minutes

## Taille de l'image

- **Avant compression**: +150 MB (repo DietPi)
- **Après premier boot**: -300 MB (nettoyage des paquets)
- **Gain net**: ~150 MB économisés

## Vérification après installation

```bash
# Vérifier que DietPi est installé
cat /boot/dietpi/.install_stage  # Doit être -1 ou 2
systemctl list-units | grep dietpi  # Services actifs
dietpi-launcher  # Interface fonctionne

# Vérifier la taille
df -h /
dpkg -l | wc -l  # Nombre de paquets (devrait être <450)
```

## Comparaison

| Aspect | Ancienne méthode | Auto-Install |
|--------|------------------|--------------|
| Approche | Copie manuelle | Installer officiel |
| Offline | ✅ Oui | ✅ Oui |
| Vrai DietPi | ❌ Non (scripts seulement) | ✅ Oui (complet) |
| Optimisé | ❌ Non (1.5 GB) | ✅ Oui (~500 MB) |
| Services actifs | ❌ Non | ✅ Oui |
| Allègement | ❌ Aucun | ✅ ~1 GB |
| Premier boot | Rapide (30s) | Long (20-30 min) |

## Logs

- **Installation**: `/var/log/dietpi-auto-install.log`
- **Flag de completion**: `/boot/dietpi/.auto-install-done`
- **Service**: `journalctl -u dietpi-auto-install.service`

## Troubleshooting

### Le service ne démarre pas

```bash
systemctl status dietpi-auto-install.service
journalctl -xe -u dietpi-auto-install.service
```

### L'installer échoue

```bash
cat /var/log/dietpi-auto-install.log
```

### Relancer manuellement

```bash
sudo rm /boot/dietpi/.auto-install-done
sudo systemctl start dietpi-auto-install.service
```

## Next Steps

1. ✅ Tester manuellement sur un SmartPi1
2. ✅ Vérifier que tout fonctionne
3. ✅ Intégrer dans le workflow
4. ✅ Générer une nouvelle image
5. ✅ Flasher et tester le premier boot automatique
