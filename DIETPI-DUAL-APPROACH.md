# DietPi Dual Approach - Documentation

## Vue d'ensemble

Deux méthodes pour générer des images DietPi, chacune optimisée pour un usage différent.

## Image A: DietPi-Ready-Auto (Usage direct)

### Caractéristiques
- **Action GitHub**: `prepare-dietpi`
- **Build time**: ~3 minutes ⚡
- **Premier boot**: ~25 minutes (installation automatique)
- **Offline**: 100% ✅
- **Taille image**: ~1.8 GB (+150 MB pour le repo DietPi)

### Fonctionnement
```
Build (3 min)
  ├── Clone repo DietPi complet
  ├── Copy dans /opt/dietpi-source
  ├── Install dietpi-auto-install.sh + service
  └── Enable service

Premier boot (25 min)
  ├── Service auto-install démarre
  ├── Patch installer pour offline
  ├── Lance installer DietPi officiel
  ├── Installation complète
  ├── Redémarre
  └── DietPi prêt! ✓
```

### Avantages
- ✅ Build ultra-rapide (3 min)
- ✅ 100% offline (tout dans l'image)
- ✅ Vrai DietPi (installer officiel)
- ✅ Système optimisé (~500 MB final)
- ✅ Pas de QEMU (simplicité)

### Inconvénients
- ⚠️ Premier boot long (25 min)
- ⚠️ Incompatible avec CustomPiOS/YumiOS

### Usage
```bash
# Flasher l'image
dd if=smartpi1-DietPi-Ready-*.img of=/dev/sdX

# Booter et attendre 25 min
# DietPi s'installe automatiquement
```

---

## Image B: DietPi-QEMU (Pour YumiOS)

### Caractéristiques
- **Action GitHub**: `convert-dietpi`
- **Build time**: ~40 minutes
- **Premier boot**: Rapide (~1 min)
- **Offline**: Non (télécharge pendant build)
- **Taille image**: ~1.5 GB

### Fonctionnement
```
Build (40 min)
  ├── Mount image
  ├── Setup QEMU + binfmt
  ├── Chroot dans l'image
  ├── Exécute installer DietPi
  ├── DietPi s'installe complètement
  ├── Unmount
  └── Image DietPi prête

Premier boot (1 min)
  └── DietPi déjà installé ✓
```

### Avantages
- ✅ Image prête immédiatement
- ✅ Premier boot rapide
- ✅ Compatible CustomPiOS/YumiOS
- ✅ DietPi complet et testé
- ✅ Aucune surprise au boot

### Inconvénients
- ⚠️ Build lent (40 min)
- ⚠️ Nécessite QEMU (complexité)
- ⚠️ Télécharge pendant le build (pas offline)
- ⚠️ Peut échouer dans l'émulateur

### Usage
```bash
# Pour YumiOS (CustomPiOS)
DOWNLOAD_URL_IMAGE="https://github.com/xtrack33/SmartPi-armbian/releases/download/latest/smartpi1-DietPi-QEMU-*.img.xz"
```

---

## Workflow GitHub Actions

```yaml
# .github/workflows/BuildImages.yml
jobs:
  # Build Armbian base
  build:
    runs-on: ubuntu-latest
    # ... build Armbian

  # Image A: Auto-Install (pour particuliers)
  dietpi-firstboot:
    name: DietPi Auto-Install (Direct Use)
    needs: build
    uses: ./actions/prepare-dietpi
    with:
      image_name: smartpi1-bookworm-...
      hw_model: 25
      distro_target: 7

  # Image B: QEMU (pour YumiOS)
  dietpi-qemu:
    name: DietPi QEMU (For YumiOS)
    needs: build
    uses: ./actions/convert-dietpi
    with:
      image_name: smartpi1-bookworm-...
      hw_model: 25
      distro_target: 7
```

---

## Artifacts générés

### Image A
```
smartpi1-DietPi-Ready-bookworm-debian12-server-2026-02-04.img.xz
  ├── Armbian base
  ├── /opt/dietpi-source/ (150 MB)
  ├── dietpi-auto-install.sh
  └── dietpi-auto-install.service (enabled)
```

### Image B
```
smartpi1-DietPi-QEMU-bookworm-debian12-server-2026-02-04.img.xz
  ├── Armbian base
  └── DietPi fully installed ✓
```

---

## Comparaison technique

| Aspect | DietPi-Ready-Auto | DietPi-QEMU |
|--------|-------------------|-------------|
| **Build** | 3 min | 40 min |
| **Premier boot** | 25 min | 1 min |
| **Total time** | 28 min | 41 min |
| **Offline** | ✅ 100% | ❌ Non |
| **QEMU** | ❌ Non | ✅ Oui |
| **Complexité** | Simple | Complexe |
| **Fiabilité build** | ✅ Élevée | ⚠️ Moyenne |
| **CustomPiOS** | ❌ Non | ✅ Oui |
| **Usage direct** | ✅ Oui | ✅ Oui |

---

## Quelle image choisir?

### Utilisez DietPi-Ready-Auto si:
- ✅ Usage direct sur hardware
- ✅ Vous voulez du 100% offline
- ✅ Le premier boot long n'est pas un problème
- ✅ Vous voulez la version la plus récente de DietPi

### Utilisez DietPi-QEMU si:
- ✅ Pour YumiOS/CustomPiOS
- ✅ Vous voulez un boot immédiat
- ✅ Vous ne voulez pas attendre au premier boot
- ✅ Vous voulez une image testée et stable

---

## Migration YumiOS

Pour utiliser l'image QEMU dans YumiOS:

```bash
# config/armbian/smartpi1
DOWNLOAD_URL_IMAGE="https://github.com/xtrack33/SmartPi-armbian/releases/download/v1.0.0/smartpi1-DietPi-QEMU-bookworm-debian12-server.img.xz"
DOWNLOAD_URL_CHECKSUM="https://github.com/xtrack33/SmartPi-armbian/releases/download/v1.0.0/smartpi1-DietPi-QEMU-bookworm-debian12-server.img.xz.sha256"
```

YumiOS recevra une image DietPi déjà installée et prête!

---

## Maintenance

### prepare-dietpi (Auto-Install)
- Code simple: ~150 lignes
- Pas de dépendances QEMU
- Facile à maintenir
- Patch de l'installer DietPi

### convert-dietpi (QEMU)
- Code complexe: ~300 lignes
- Dépend de QEMU, binfmt
- Plus difficile à debugger
- Émulation ARM complète

---

## Conclusion

**Les deux approches sont complémentaires:**
- DietPi-Ready-Auto → Particuliers, offline, simple
- DietPi-QEMU → YumiOS, stable, immédiat

**Recommandation:** Maintenir les deux pour couvrir tous les cas d'usage!
