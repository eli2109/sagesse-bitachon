# Comment remplacer les phrases

## Fichier concerné

`assets/phrases.json`

## Format attendu

Le fichier doit contenir un tableau JSON de chaînes de caractères :

```json
[
  "Première phrase ou idée résumée...",
  "Deuxième phrase...",
  "..."
]
```

## Étapes pour mettre à jour

1. Ouvrez `assets/phrases.json` dans un éditeur de texte.
2. Remplacez tout le contenu par votre liste complète de phrases.
3. Vérifiez que le fichier reste un JSON valide (guillemets doubles, virgules entre les éléments).
4. Recompilez l'application :
   ```bash
   flutter build apk --release
   ```

## Notes importantes

- L'application lit uniquement ce fichier ; elle ne crée pas les phrases.
- Si vous modifiez le **nombre** de phrases, l'état de lecture sauvegardé sera réinitialisé automatiquement au prochain lancement.
- Pour forcer un nouveau mélange sans changer les phrases, utilisez le bouton **Nouveau cycle** (icône shuffle) dans l'application.