import pandas as pd
import random

# --- Sample Data ---
def get_sample_data():
    """Returns a dictionary of sample dataframes."""

    card_brands = ['VISA', 'MASTERCARD', 'JCB', 'AMEX']
    card_types = ['CREDIT', 'DEBIT']
    banks = ['BCA', 'BNI', 'MANDIRI', 'BRI', 'CIMB', 'OTHER']
    currencies = ['IDR']
    client_types = ['WEB', 'MOBILE', 'API']

    legacy_charges_data = {
        'business_id': [f'bu-{random.randint(100, 999)}' for _ in range(100)],
        'card_brand': [random.choice(card_brands) for _ in range(100)],
        'card_type': [random.choice(card_types) for _ in range(100)],
        'issuing_bank_name': [random.choice(banks) for _ in range(100)],
        'currency': [random.choice(currencies) for _ in range(100)],
        'installment_count': [random.choice([None, 3, 6, 12]) for _ in range(100)],
        'client_type': [random.choice(client_types) for _ in range(100)],
        'merchant_id': [f'merch-{random.choice(["abc", "def", "ghi", "jkl", "mno"])}' for _ in range(100)],
        'mid_label': [random.choice([None, 'promo-mid', 'special-offer']) for _ in range(100)]
    }

    merchant_send_mid_label_data = {
        'business_id': [f'bu-excluded-{i}' for i in range(1, 11)]
    }

    merchant_excluded_data = {
        'business_id': [f'bu-excluded-{i}' for i in range(11, 21)]
    }

    return {
        "legacy_charges": pd.DataFrame(legacy_charges_data),
        "merchant_send_mid_label": pd.DataFrame(merchant_send_mid_label_data),
        "merchant_excluded": pd.DataFrame(merchant_excluded_data)
    }

# --- Main Script ---
def main():
    """
    Generates sample data and saves it to CSV files.
    """
    print("Generating sample data CSVs...")

    dataframes = get_sample_data()

    for name, df in dataframes.items():
        file_path = f"sample_data/{name}.csv"
        df.to_csv(file_path, index=False)
        print(f"Successfully created '{file_path}'")

    print("\nCSV files generated. You can now manually upload them to Google Sheets.")

if __name__ == "__main__":
    main()
