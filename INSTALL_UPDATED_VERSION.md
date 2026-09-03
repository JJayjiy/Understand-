# Install the updated phonetics pipeline

1. Keep your current `melodie-phonetics` branch selected in GitHub Desktop.
2. Make a backup copy of your current `Understand-` folder.
3. Copy the files from this ZIP into `Understand-` and choose **Replace** when
   macOS asks about files with the same names.
4. In the VS Code terminal, make sure the prompt is inside `Understand-`, then:

```bash
source .venv/bin/activate
pip install -r requirements.txt
pip install -r requirements-phonetics.txt
streamlit run app.py
```

The second installation is large because Allosaurus uses PyTorch. The normal
app and manual phonetic comparison still work if Allosaurus cannot install.

## First safe test

Use your own short WAV recording, not participant data:

- Speaker code: `S01`
- Clip ID: `S01-C001`
- Confirmed text: the exact sentence you recorded
- Phone source: **Automatic Allosaurus estimate** if available

Click **Analyze phones**. Review each mismatch before marking it as a speaker
pattern. Three reviewed examples of the same mapping create a candidate rule.

## Git checkpoint

After the app runs, commit the changed files on `melodie-phonetics` with:

```text
Add reviewed phonological analysis pipeline
```

Do not commit `data/`, audio, `.env`, or `.venv`.
