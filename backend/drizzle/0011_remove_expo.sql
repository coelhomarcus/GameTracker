-- O Expo deixou de existir: as instalações dele são descartadas antes de o tipo perder o valor.
DELETE FROM "push_installations" WHERE "provider" = 'expo';--> statement-breakpoint
ALTER TABLE "push_installations" ALTER COLUMN "provider" SET DATA TYPE text;--> statement-breakpoint
DROP TYPE "public"."push_provider";--> statement-breakpoint
CREATE TYPE "public"."push_provider" AS ENUM('fcm');--> statement-breakpoint
ALTER TABLE "push_installations" ALTER COLUMN "provider" SET DATA TYPE "public"."push_provider" USING "provider"::"public"."push_provider";--> statement-breakpoint
ALTER TABLE "users" DROP COLUMN "expo_push_token";