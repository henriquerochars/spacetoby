-- Local email/password accounts. Account IDs are used as Player.auth_user_id.
CREATE TABLE "accounts" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "email" VARCHAR(320) NOT NULL,
    "password_hash" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "accounts_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "accounts_email_key" ON "accounts"("email");
