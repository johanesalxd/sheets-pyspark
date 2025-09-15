import gspread
from oauth2client.service_account import ServiceAccountCredentials

# --- Configuration ---
CREDENTIALS_FILE = '../drive-api.json'
SCOPES = ["https://spreadsheets.google.com/feeds", "https://www.googleapis.com/auth/drive"]

SHEET_IDS = {
    "legacy_charges": "1kQENu6sumzEQX60fjQtgmXvwPGlUfaNRgW7v_TWFUXo",
    "merchant_excluded": "1orVBlPP77HTt9d8x-lC1Oo5xrPp0r1FgVUQ-43DYqYc",
    "merchant_send_mid_label": "1_8sm8QciAU3T8oDlNS1Pfj-GQlmlJBrAi1TYdnnMlkw"
}

def main():
    """
    Tests read access to the provided Google Sheet IDs.
    """
    print("Authenticating with Google...")
    try:
        creds = ServiceAccountCredentials.from_json_keyfile_name(CREDENTIALS_FILE, SCOPES)
        client = gspread.authorize(creds)
    except Exception as e:
        print(f"Error during authentication: {e}")
        return

    all_successful = True
    for name, sheet_id in SHEET_IDS.items():
        try:
            print(f"--- Testing access to '{name}' (ID: {sheet_id}) ---")
            sheet = client.open_by_key(sheet_id)
            worksheet = sheet.get_worksheet(0)
            first_row = worksheet.row_values(1)
            print(f"Successfully read first row: {first_row}")
            print("Access confirmed.\n")
        except gspread.exceptions.APIError as e:
            print(f"API Error accessing '{name}': {e}")
            print("Please ensure the sheet is shared with the service account email: drive-api@johanesa-playground-326616.iam.gserviceaccount.com\n")
            all_successful = False
        except Exception as e:
            print(f"An unexpected error occurred while accessing '{name}': {e}\n")
            all_successful = False

    if all_successful:
        print("All sheets accessed successfully!")
    else:
        print("There were errors accessing one or more sheets.")

if __name__ == "__main__":
    main()
