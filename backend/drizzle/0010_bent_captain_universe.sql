CREATE TYPE "public"."push_provider" AS ENUM('expo', 'fcm');--> statement-breakpoint
CREATE TABLE "push_installations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"installation_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"provider" "push_provider" NOT NULL,
	"platform" varchar(20) NOT NULL,
	"token" text NOT NULL,
	"active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "push_installations_installation_id_unique" UNIQUE("installation_id"),
	CONSTRAINT "push_installations_provider_token_unique" UNIQUE("provider","token")
);
--> statement-breakpoint
ALTER TABLE "push_installations" ADD CONSTRAINT "push_installations_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "push_installations_user_id_idx" ON "push_installations" USING btree ("user_id");