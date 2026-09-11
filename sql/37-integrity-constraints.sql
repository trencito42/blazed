-- Deliberately fail if duplicate slots already exist. Silently deleting or
-- merging rows could destroy metadata-bearing player items.
ALTER TABLE character_inventory
    ADD UNIQUE INDEX IF NOT EXISTS uq_character_inventory_slot (character_id, slot);

-- Preserve the oldest verified email and clear only invalid duplicate aliases
-- before applying the login identity invariant.
UPDATE accounts newer
JOIN accounts older
  ON LOWER(older.email) = LOWER(newer.email)
 AND older.id < newer.id
SET newer.email = NULL
WHERE newer.email IS NOT NULL AND newer.email <> '';

ALTER TABLE accounts
    ADD UNIQUE INDEX IF NOT EXISTS uq_accounts_email (email);

CREATE INDEX IF NOT EXISTS idx_phone_messages_sender_id ON phone_messages (sender_character_id, id);
CREATE INDEX IF NOT EXISTS idx_phone_messages_receiver_id ON phone_messages (receiver_character_id, id);
