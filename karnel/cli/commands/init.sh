#!/usr/bin/env bash

import "@/utils/log"
import "@/utils/colors"

LOG_FILE="$KARNEL_CACHE/init_project.log"

init_help() {
	echo
	box "Karnel Project Initializer"
	echo
	log_info "Usage: karnel init <template>"
	echo
	log_info "Run this inside an existing project to configure it."
	echo
	separator_section "Available Templates"
	echo
	printf "    ${D_CYAN}%-12s${NC} %s\n" "next" "Configure Next.js project"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "react" "Configure React + Vite project"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "nest" "Configure NestJS project"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "express" "Configure Express.js API"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "python" "Configure FastAPI project"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "go" "Configure Go (Gin) project"
	printf "    ${D_CYAN}%-12s${NC} %s\n" "rust" "Configure Rust (Axum) project"
	echo
	separator_section "Examples"
	echo
	printf "    ${D_CYAN}cd my-next-app && karnel init next${NC}\n"
	printf "    ${D_CYAN}cd my-python-app && karnel init python${NC}\n"
	printf "    ${D_CYAN}cd my-go-app && karnel init go${NC}\n"
	printf "    ${D_CYAN}cd my-rust-app && karnel init rust${NC}\n"
	echo
}

check_project_exists() {
	if [[ ! -f "package.json" ]]; then
		log_error "No project found in current directory"
		log_info "Make sure you're inside a project directory"
		return 1
	fi
	return 0
}

# ===== NEXT.JS =====
configure_next() {
	separator
	box "Configuring Next.js Project"
	separator
	echo
	check_project_exists || return 1

	if ! grep -q "next" package.json 2>/dev/null; then
		log_warn "This doesn't appear to be a Next.js project"
		read_confirm "Continue anyway?" CONFIRM
		[[ "$CONFIRM" != "y" ]] && { log_warn "Cancelled"; return 0; }
	fi

	log_info "Installing dependencies..."
	if loading "Installing dependencies" _install_next_deps; then
		log_success "Dependencies installed"
		echo
		list_item "axios, lucide-react, framer-motion, sonner, zod"
		list_item "react-hook-form, @hookform/resolvers"
		list_item "@tanstack/react-query, zustand, tailwindcss"
		list_item "prettier, prettier-plugin-tailwindcss"
		echo
	else
		log_warn "Some dependencies failed to install"
	fi

	log_info "Setting up structure..."
	mkdir -p src/components/ui src/lib src/hooks src/types src/config src/store 2>/dev/null

	# Crear .prettierrc
	cat >.prettierrc <<'EOF'
{
  "plugins": ["prettier-plugin-tailwindcss"]
}
EOF
	log_success "Created .prettierrc"

	log_info "Creating karnel landing page..."
[[ -f "src/app/page.tsx" ]] && cat >src/app/page.tsx <<'EOF'
"use client"
import { motion } from "framer-motion"
import { Terminal, Code2, Rocket } from "lucide-react"
import { Toaster } from "sonner"

export default function Home() {
  return (
    <main className="min-h-screen bg-gradient-to-b from-black via-slate-950 to-slate-900">
      <Toaster position="top-center" richColors />
      <div className="container mx-auto px-4 py-20">
        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} className="text-center">
          <motion.div initial={{ scale: 0 }} animate={{ scale: 1 }} transition={{ delay: 0.2, type: "spring" }} className="mb-8 flex justify-center">
            <div className="p-4 bg-gradient-to-br from-blue-500 to-purple-600 rounded-2xl shadow-2xl">
              <Terminal className="w-16 h-16 text-white" />
            </div>
          </motion.div>
          <motion.h1 initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.3 }} className="text-5xl md:text-7xl font-bold mb-6 bg-gradient-to-r from-blue-400 via-purple-400 to-pink-400 bg-clip-text text-transparent">
            karnel
          </motion.h1>
          <motion.p initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.4 }} className="text-xl md:text-2xl text-slate-400 mb-4">
            Comunidad de Desarrollo y Tecnología
          </motion.p>
          <motion.p initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.5 }} className="text-lg text-slate-500 mb-12 max-w-2xl mx-auto">
            Este proyecto fue creado con herramientas de la comunidad karnel.
          </motion.p>
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.6 }} className="grid md:grid-cols-3 gap-6 mb-12 max-w-4xl mx-auto">
            <div className="p-6 rounded-xl bg-slate-900/50 border border-slate-800"><Code2 className="w-12 h-12 text-blue-400 mb-4 mx-auto" /><h3 className="text-lg font-semibold text-white mb-2">Código de Calidad</h3></div>
            <div className="p-6 rounded-xl bg-slate-900/50 border border-slate-800"><Rocket className="w-12 h-12 text-purple-400 mb-4 mx-auto" /><h3 className="text-lg font-semibold text-white mb-2">Proyectos Reales</h3></div>
            <div className="p-6 rounded-xl bg-slate-900/50 border border-slate-800"><Terminal className="w-12 h-12 text-pink-400 mb-4 mx-auto" /><h3 className="text-lg font-semibold text-white mb-2">Comunidad Activa</h3></div>
          </motion.div>
          <motion.div initial={{ opacity: 0, scale: 0.8 }} animate={{ opacity: 1, scale: 1 }} transition={{ delay: 0.7 }} className="w-full max-w-sm mx-auto">
            <button type="button" onClick={() => window.open("mailto:israelmarques1024@gmail.com", "_blank")} className="w-full rounded-md bg-gradient-to-r from-blue-500 to-purple-600 px-8 py-6 text-lg font-semibold text-white hover:from-blue-600 hover:to-purple-700">
               <Rocket className="w-5 h-5 mr-2" /> Contato: israelmarques1024@gmail.com
            </button>
          </motion.div>
          <motion.p initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.8 }} className="mt-16 text-sm text-slate-600">Built with ❤️ using karnel tools</motion.p>
        </motion.div>
      </div>
    </main>
  )
}
EOF

	# Actualizar package.json para usar --webpack
	if [[ -f "package.json" ]]; then
		log_info "Updating package.json scripts..."
		if ! command -v jq &>/dev/null; then
			log_warn "jq not found — skipping package.json update"
		else
			local temp
			temp=$(mktemp "${TMPDIR:-${KARNEL_CACHE:-$HOME/.cache/karnel}}/karnel-XXXXXX")
			jq '.scripts.dev = "next dev --webpack" | .scripts.build = "next build --webpack" | .scripts.start = "next start"' package.json > "$temp" && mv "$temp" package.json
			log_success "Added --webpack flag to dev and build scripts"
		fi
	fi

	[[ -f "src/app/layout.tsx" ]] && cat >src/app/layout.tsx <<'EOF'
import type { Metadata } from "next"
import { Inter } from "next/font/google"
import "./globals.css"
const inter = Inter({ subsets: ["latin"] })
export const metadata: Metadata = {
  title: "karnel - Comunidad de Desarrollo",
  description: "Únete a la comunidad karnel",
}
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (<html lang="es"><body className={inter.className}>{children}</body></html>)
}
EOF

	echo
	separator
	log_success "Next.js configured!"
	separator
	echo
	list_item "Dependencies installed"
	list_item "karnel landing page created"
	list_item "Prettier configured"
	echo
	log_info "Next steps:"
	echo
	list_item "Initialize shadcn: ${D_CYAN}npx shadcn@latest init${NC}"
	list_item "Add button: ${D_CYAN}npx shadcn@latest add button${NC}"
	list_item "Start: ${D_CYAN}npm run dev${NC} (with --webpack)"
	echo
}

_install_next_deps() {
	npm install axios lucide-react framer-motion sonner zod react-hook-form @hookform/resolvers @tanstack/react-query zustand tailwindcss &>"$LOG_FILE"
	npm install -D prettier prettier-plugin-tailwindcss &>>"$LOG_FILE"
}

# ===== REACT + VITE =====
configure_react() {
	separator
	box "Configuring React + Vite Project"
	separator
	echo
	check_project_exists || return 1

	if ! grep -q "vite" package.json 2>/dev/null; then
		log_warn "This doesn't appear to be a Vite project"
		read_confirm "Continue anyway?" CONFIRM
		[[ "$CONFIRM" != "y" ]] && { log_warn "Cancelled"; return 0; }
	fi

	log_info "Installing dependencies..."
	if loading "Installing dependencies" _install_react_deps; then
		log_success "Dependencies installed"
		echo
		list_item "axios, lucide-react, framer-motion, sonner, zod"
		list_item "react-hook-form, @hookform/resolvers"
		list_item "@tanstack/react-query, zustand, tailwindcss"
		list_item "prettier, prettier-plugin-tailwindcss"
		echo
	else
		log_warn "Some dependencies failed to install"
	fi

	log_info "Setting up structure..."
	mkdir -p src/components/ui src/lib src/hooks src/types src/config src/store src/pages 2>/dev/null

	# Crear .prettierrc
	cat >.prettierrc <<'EOF'
{
  "plugins": ["prettier-plugin-tailwindcss"]
}
EOF
	log_success "Created .prettierrc"

	log_info "Creating karnel landing page..."
	if [[ -f "src/App.tsx" ]]; then
		cat >src/App.tsx <<'EOF'
import { Button } from "./components/ui/Button"
import { motion } from "framer-motion"
import { Terminal, Code2, Rocket } from "lucide-react"
import { Toaster } from "sonner"

function App() {
  return (
    <main className="min-h-screen bg-gradient-to-b from-black via-slate-950 to-slate-900">
      <Toaster position="top-center" richColors />
      <div className="container mx-auto px-4 py-20">
        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} className="text-center">
          <motion.div initial={{ scale: 0 }} animate={{ scale: 1 }} transition={{ delay: 0.2, type: "spring" }} className="mb-8 flex justify-center">
            <div className="p-4 bg-gradient-to-br from-blue-500 to-purple-600 rounded-2xl shadow-2xl">
              <Terminal className="w-16 h-16 text-white" />
            </div>
          </motion.div>
          <motion.h1 initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.3 }} className="text-5xl md:text-7xl font-bold mb-6 bg-gradient-to-r from-blue-400 via-purple-400 to-pink-400 bg-clip-text text-transparent">karnel</motion.h1>
          <motion.p initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.4 }} className="text-xl md:text-2xl text-slate-400 mb-4">Comunidad de Desarrollo y Tecnología</motion.p>
          <motion.p initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.5 }} className="text-lg text-slate-500 mb-12 max-w-2xl mx-auto">Este proyecto fue creado con herramientas de la comunidad karnel.</motion.p>
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.6 }} className="grid md:grid-cols-3 gap-6 mb-12 max-w-4xl mx-auto">
            <div className="p-6 rounded-xl bg-slate-900/50 border border-slate-800"><Code2 className="w-12 h-12 text-blue-400 mb-4 mx-auto" /><h3 className="text-lg font-semibold text-white mb-2">Código de Calidad</h3></div>
            <div className="p-6 rounded-xl bg-slate-900/50 border border-slate-800"><Rocket className="w-12 h-12 text-purple-400 mb-4 mx-auto" /><h3 className="text-lg font-semibold text-white mb-2">Proyectos Reales</h3></div>
            <div className="p-6 rounded-xl bg-slate-900/50 border border-slate-800"><Terminal className="w-12 h-12 text-pink-400 mb-4 mx-auto" /><h3 className="text-lg font-semibold text-white mb-2">Comunidad Activa</h3></div>
          </motion.div>
          <motion.div initial={{ opacity: 0, scale: 0.8 }} animate={{ opacity: 1, scale: 1 }} transition={{ delay: 0.7 }} className="w-full max-w-sm mx-auto">
            <Button size="lg" onClick={() => window.open("mailto:israelmarques1024@gmail.com", "_blank")} className="w-full bg-gradient-to-r from-blue-500 to-purple-600 text-white px-8 py-6 text-lg">
              <Rocket className="w-5 h-5 mr-2" /> Contato: israelmarques1024@gmail.com
            </Button>
          </motion.div>
          <motion.p initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.8 }} className="mt-16 text-sm text-slate-600">Built with ❤️ using karnel tools</motion.p>
        </motion.div>
      </div>
    </main>
  )
}
export default App
EOF
		log_success "Created landing page"
	fi

	if [[ ! -f "src/components/ui/Button.tsx" ]]; then
		mkdir -p src/components/ui
		cat >src/components/ui/Button.tsx <<'EOF'
import { ButtonHTMLAttributes, forwardRef } from 'react'
import { clsx } from 'clsx'
import { twMerge } from 'tailwind-merge'
function cn(...inputs: any[]) { return twMerge(clsx(inputs)) }
interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'default' | 'outline' | 'ghost'
  size?: 'sm' | 'md' | 'lg'
}
export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = 'default', size = 'md', children, ...props }, ref) => {
    return (
      <button className={cn('inline-flex items-center justify-center rounded-md font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50',
        { 'bg-primary text-primary-foreground hover:bg-primary/90': variant === 'default',
          'border border-input hover:bg-accent hover:text-accent-foreground': variant === 'outline',
          'hover:bg-accent hover:text-accent-foreground': variant === 'ghost',
          'h-9 px-3 text-sm': size === 'sm', 'h-10 px-4': size === 'md', 'h-11 px-8': size === 'lg' },
        className)} ref={ref} {...props}>{children}</button>
    )
  }
)
Button.displayName = 'Button'
EOF
		log_success "Created Button component"
	fi

	echo
	separator
	log_success "React + Vite configured!"
	separator
	echo
	list_item "Dependencies installed"
	list_item "Prettier configured"
	echo
	list_item "Start: ${D_CYAN}npm run dev${NC}"
	echo
}

_install_react_deps() {
	npm install axios lucide-react framer-motion sonner zod react-hook-form @hookform/resolvers @tanstack/react-query zustand tailwindcss clsx tailwind-merge &>"$LOG_FILE"
	npm install -D prettier prettier-plugin-tailwindcss &>>"$LOG_FILE"
}

# ===== EXPRESS.JS =====
configure_express() {
	separator
	box "Configuring Express.js Project"
	separator
	echo
	check_project_exists || return 1

	if ! grep -q "express" package.json 2>/dev/null; then
		log_warn "This doesn't appear to be an Express project"
		read_confirm "Continue anyway?" CONFIRM
		[[ "$CONFIRM" != "y" ]] && { log_warn "Cancelled"; return 0; }
	fi

	log_info "Installing dependencies..."
	if loading "Installing dependencies" _install_express_deps; then
		log_success "Dependencies installed"
		echo
		list_item "express, pg, typeorm, reflect-metadata"
		list_item "jsonwebtoken, cookie-parser, morgan, cors"
		list_item "bcryptjs, helmet, cloudinary, multer"
		list_item "express-rate-limit, zod"
		echo
	else
		log_warn "Some dependencies failed to install"
	fi

	log_info "Installing devDependencies..."
	if loading "Installing devDependencies" _install_express_dev; then
		log_success "devDependencies installed"
		echo
		list_item "typescript, ts-node-dev, tsconfig-paths, tsc-alias"
		list_item "@types/* (all type definitions)"
		echo
	else
		log_warn "Some devDependencies failed to install"
	fi

	log_info "Creating folder structure..."
	_setup_express_structure

	log_info "Creating configuration files..."
	_create_express_config

	echo
	separator
	log_success "Express.js configured!"
	separator
	echo
	list_item "Start: ${D_CYAN}npm run dev${NC}"
	list_item "Build: ${D_CYAN}npm run build${NC}"
	list_item "Migrations: ${D_CYAN}npm run mg:run${NC}"
	echo
}

_install_express_deps() {
	npm install express pg typeorm reflect-metadata jsonwebtoken cookie-parser morgan cors bcryptjs helmet cloudinary multer express-rate-limit tsconfig-paths zod &>"$LOG_FILE"
}

_install_express_dev() {
	npm install -D typescript ts-node-dev tsconfig-paths tsc-alias @types/node @types/multer @types/morgan @types/jsonwebtoken @types/helmet @types/express @types/cors @types/cookie-parser @types/bcryptjs &>>"$LOG_FILE"
}

_setup_express_structure() {
	mkdir -p src/controllers 2>/dev/null
	mkdir -p src/middlewares 2>/dev/null
	mkdir -p src/repositories 2>/dev/null
	mkdir -p src/routes 2>/dev/null
	mkdir -p src/schemas 2>/dev/null
	mkdir -p src/services 2>/dev/null
	mkdir -p src/types 2>/dev/null
	mkdir -p src/utils 2>/dev/null
	mkdir -p src/config 2>/dev/null
	mkdir -p src/database/migrations 2>/dev/null
	mkdir -p src/database/seeds 2>/dev/null
	mkdir -p src/entities 2>/dev/null
	log_success "Created folder structure"
}

_create_express_config() {
	cat >tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "moduleResolution": "node",
    "baseUrl": ".",
    "paths": { "@/*": ["src/*"] },
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true,
    "strictPropertyInitialization": false
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
EOF
	log_success "Created tsconfig.json"

	cat >.env.example <<'EOF'
NODE_ENV=development
PORT=4000
DB_NAME=postgres
DATABASE_URL=postgresql://user:changeme@localhost:5432/dbname
JWT_SECRET=CHANGE_ME_TO_A_RANDOM_STRING
FRONTEND_URL=http://localhost:3000
CLOUDINARY_URL=cloudinary://YOUR_API_KEY:YOUR_API_SECRET@YOUR_CLOUD_NAME
EOF
	log_success "Created .env.example"

	cat >src/config/env.ts <<'EOF'
export const NODE_ENV = process.env.NODE_ENV || "development";
export const PORT = Number(process.env.PORT) || 4000;
export const DB_NAME = process.env.DB_NAME || "postgres";
export const DATABASE_URL = process.env.DATABASE_URL;
export const JWT_SECRET = process.env.JWT_SECRET as string;
export const FRONTEND_URL = (process.env.FRONTEND_URL as string) || "http://localhost:3000";
EOF
	log_success "Created src/config/env.ts"

	cat >src/database/data-source.ts <<'EOF'
import "reflect-metadata";
import { DataSource } from "typeorm";
import { DATABASE_URL, NODE_ENV } from "@/config/env";

const isDevelopment = NODE_ENV === "development";
const isProduction = NODE_ENV === "production";

export const AppDataSource = new DataSource({
  type: "postgres",
  url: DATABASE_URL,
  ssl: isDevelopment ? false : { rejectUnauthorized: true },
  synchronize: isDevelopment,
  logging: isDevelopment ? ["query", "error"] : false,
  entities: [],
  migrations: isDevelopment
    ? [__dirname + "/migrations/*.ts"]
    : [__dirname + "/migrations/*.js"],
  migrationsRun: isDevelopment,
  extra: {
    max: isProduction ? 10 : 20,
  },
});
EOF
	log_success "Created src/database/data-source.ts"

	cat >src/app.ts <<'EOF'
import express from "express";
import rateLimit from "express-rate-limit";
import helmet from "helmet";
import morgan from "morgan";
import cors from "cors";
import cookieParser from "cookie-parser";
import { FRONTEND_URL } from "@/config/env";

const app = express();

// monitorear peticiones HTTP (logger)
app.use(morgan("dev"));

// proteger cabeceras HTTP (seguridad)
app.use(helmet());

// habilitar acceso desde otros orígenes
app.use(
  cors({
    origin: FRONTEND_URL,
    credentials: true,
  }),
);

// limitar número de peticiones
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// parsear JSON en el body
app.use(express.json());

// manejar cookies
app.use(cookieParser());

export default app;
EOF
	log_success "Created src/app.ts"

	cat >src/index.ts <<'EOF'
import app from "@/app";
import { DB_NAME, PORT } from "@/config/env";
import { AppDataSource } from "@/database/data-source";

async function main() {
  try {
    await AppDataSource.initialize();
    console.log(" Connected to:", DB_NAME);
    app.listen(PORT, () => {
      console.log(" http://localhost:" + PORT);
    });
  } catch (error) {
    console.error("Internal server error:", error);
  }
}

main();
EOF
	log_success "Created src/index.ts"

	# Agregar scripts al package.json
	if [[ -f "package.json" ]]; then
		log_info "Adding scripts to package.json..."
		if ! command -v jq &>/dev/null; then
			log_warn "jq not found — skipping package.json update"
		else
		local temp
		temp=$(mktemp "${TMPDIR:-${KARNEL_CACHE:-$HOME/.cache/karnel}}/karnel-XXXXXX")
		jq '.scripts += {
      "dev": "ts-node-dev --require tsconfig-paths/register --env-file=.env --respawn src/index.ts",
      "build": "tsc && tsc-alias -p tsconfig.json",
      "start": "node dist/index.js",
      "typeorm": "ts-node-dev --require tsconfig-paths/register --env-file=.env ./node_modules/typeorm/cli.js",
      "mg:gen": "npm run typeorm -- migration:generate -d src/database/data-source.ts",
      "mg:create": "npm run typeorm -- migration:create",
      "mg:run": "npm run typeorm -- migration:run -d src/database/data-source.ts",
      "mg:revert": "npm run typeorm -- migration:revert -d src/database/data-source.ts",
      "mg:show": "npm run typeorm -- migration:show -d src/database/data-source.ts"
    }' package.json > "$temp" && mv "$temp" package.json
		log_success "Added scripts to package.json"
		fi
	fi
}

# ===== NESTJS =====
configure_nest() {
	separator
	box "Configuring NestJS Project"
	separator
	echo
	check_project_exists || return 1

	if ! grep -q "@nestjs" package.json 2>/dev/null; then
		log_warn "This doesn't appear to be a NestJS project"
		read_confirm "Continue anyway?" CONFIRM
		[[ "$CONFIRM" != "y" ]] && { log_warn "Cancelled"; return 0; }
	fi

	log_info "Installing NestJS dependencies..."
	if loading "Installing dependencies" _install_nest_deps; then
		log_success "Dependencies installed"
		echo
		list_item "@nestjs/typeorm, typeorm, pg"
		list_item "@nestjs/jwt, @nestjs/passport"
		list_item "class-validator, class-transformer"
		list_item "bcryptjs, helmet, cloudinary"
		echo
	else
		log_warn "Some dependencies failed to install"
	fi

	echo
	separator
	log_success "NestJS configured!"
	separator
	echo
	list_item "Start: ${D_CYAN}npm run start:dev${NC}"
	echo
}

_install_nest_deps() {
	npm install @nestjs/typeorm typeorm pg @nestjs/jwt @nestjs/passport passport passport-jwt passport-local class-validator class-transformer bcryptjs helmet cloudinary &>>"$LOG_FILE"
	npm install -D @types/passport-jwt @types/passport-local @types/bcryptjs &>>"$LOG_FILE"
}

configure_python() {
	separator
	box "Configuring Python (FastAPI) Project"
	separator
	echo

	local orm_choice db_choice docker_choice
	read_select "Select database ORM" orm_choice "SQLModel" "SQLAlchemy" "None"
	read_select "Select database provider" db_choice "SQLite" "PostgreSQL"
	read_select "Enable Docker & Udocker support?" docker_choice "Yes" "No"

	log_info "Creating folder structure..."
	mkdir -p app/api/v1/endpoints app/karnel app/models app/schemas scripts 2>/dev/null

	# Create app/karnel/config.py
	cat >app/karnel/config.py <<'EOF'
import os
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    APP_NAME: str = "Karnel FastAPI"
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./sql_app.db")
    API_V1_STR: str = "/api/v1"

settings = Settings()
EOF
	log_success "Created app/karnel/config.py"

	# Create app/models/item.py
	if [[ "$orm_choice" == "SQLModel" ]]; then
		cat >app/models/item.py <<'EOF'
from typing import Optional
from sqlmodel import Field, SQLModel

class Item(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    title: str
    description: Optional[str] = None
EOF
	elif [[ "$orm_choice" == "SQLAlchemy" ]]; then
		cat >app/models/item.py <<'EOF'
from sqlalchemy import Column, Integer, String
from app.karnel.db import Base

class Item(Base):
    __tablename__ = "items"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, index=True)
    description = Column(String, nullable=True)
EOF
	fi
	log_success "Created app/models/item.py"

	# Create app/karnel/db.py
	if [[ "$orm_choice" == "SQLModel" ]]; then
		cat >app/karnel/db.py <<'EOF'
from sqlmodel import create_engine, Session, SQLModel
from app.karnel.config import settings

engine = create_engine(settings.DATABASE_URL, echo=True)

def get_session():
    with Session(engine) as session:
        yield session
EOF
	elif [[ "$orm_choice" == "SQLAlchemy" ]]; then
		cat >app/karnel/db.py <<'EOF'
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from app.karnel.config import settings

engine = create_engine(settings.DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_session():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
EOF
	else
		cat >app/karnel/db.py <<'EOF'
# No ORM configured
EOF
	fi
	log_success "Created app/karnel/db.py"

	# Create app/api/v1/endpoints/items.py
	cat >app/api/v1/endpoints/items.py <<'EOF'
from fastapi import APIRouter, Depends
from typing import List

router = APIRouter()

@router.get("/")
def get_items():
    return [{"id": 1, "title": "First Item", "description": "Karnel template item"}]
EOF
	log_success "Created app/api/v1/endpoints/items.py"

	# Create app/main.py
	cat >app/main.py <<'EOF'
from fastapi import FastAPI
from app.karnel.config import settings
from app.api.v1.endpoints import items

app = FastAPI(title=settings.APP_NAME, version="0.1.0")

app.include_router(items.router, prefix=f"{settings.API_V1_STR}/items", tags=["items"])

@app.get("/")
def read_root():
    return {"message": "Welcome to Karnel FastAPI!", "status": "healthy"}
EOF
	log_success "Created app/main.py"

	# Create requirements.txt
	if [[ ! -f "requirements.txt" ]]; then
		cat >requirements.txt <<EOF
fastapi>=0.100.0
uvicorn[standard]>=0.22.0
pydantic>=2.0
pydantic-settings>=2.0
EOF
		if [[ "$orm_choice" == "SQLModel" ]]; then
			echo "sqlmodel>=0.0.8" >>requirements.txt
		elif [[ "$orm_choice" == "SQLAlchemy" ]]; then
			echo "sqlalchemy>=2.0" >>requirements.txt
		fi
		if [[ "$db_choice" == "PostgreSQL" ]]; then
			echo "psycopg2-binary>=2.9" >>requirements.txt
		fi
		log_success "Created requirements.txt"
	fi

	# Create .env
	if [[ ! -f ".env" ]]; then
		if [[ "$db_choice" == "SQLite" ]]; then
			echo "DATABASE_URL=sqlite:///./sql_app.db" >.env
		else
			echo "DATABASE_URL=postgresql://postgres:postgres@localhost:5432/mydb" >.env
		fi
		log_success "Created .env"
	fi

	# Create Dockerfile
	if [[ "$docker_choice" == "Yes" ]]; then
		cat >Dockerfile <<'EOF'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF
		cat >docker-compose.yml <<'EOF'
version: '3.8'

services:
  web:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - .:/app
    environment:
      - DATABASE_URL=postgresql://postgres:postgres@db:5432/mydb
    depends_on:
      - db

  db:
    image: postgres:15-alpine
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=mydb
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
EOF
		# Udocker runner helper for Termux
		cat >scripts/run_udocker.sh <<'EOF'
#!/usr/bin/bash
if ! command -v udocker &>/dev/null; then
  echo "udocker is not installed. Run: karnel install dev --udocker"
  exit 1
fi
echo "Building container with udocker..."
udocker create --name=fastapi_app python:3.11-slim
# Additional setup could be scripted here.
EOF
		chmod +x scripts/run_udocker.sh
		log_success "Created Docker, docker-compose and Udocker scripts"
	fi

	# Create run.sh
	cat >scripts/run.sh <<'EOF'
#!/usr/bin/bash
uvicorn app.main:app --reload
EOF
	chmod +x scripts/run.sh

	# Create README.md
	cat >README.md <<EOF
# $orm_choice FastAPI Project

Este projeto foi inicializado pelo **Karnel** utilizando boas práticas de desenvolvimento.

## Estrutura do Projeto
- \`app/main.py\`: Ponto de entrada do FastAPI.
- \`app/karnel/\`: Configurações globais e banco de dados.
- \`app/api/\`: Endpoints divididos por versão.
- \`app/models/\`: Definição dos modelos ORM ($orm_choice).
- \`scripts/\`: Scripts utilitários de execução.

## Como Executar
1. Instale as dependências:
   \`\`\`bash
   pip install -r requirements.txt
   \`\`\`
2. Execute a aplicação:
   \`\`\`bash
   ./scripts/run.sh
   \`\`\`
EOF
	log_success "Created README.md"

	log_success "Python (FastAPI) project configured!"
	log_info "Run: pip install -r requirements.txt && ./scripts/run.sh"
	echo
}

configure_go() {
	separator
	box "Configuring Go Project"
	separator
	echo

	local framework_choice db_choice
	read_select "Select Go web framework" framework_choice "Gin" "Fiber"
	read_select "Select database provider" db_choice "PostgreSQL" "SQLite" "None"

	log_info "Initializing Go modules if needed..."
	if [[ ! -f "go.mod" ]]; then
		local mod_name
		mod_name=$(basename "$(pwd)")
		go mod init "$mod_name" 2>/dev/null || go mod init project
		log_success "Created go.mod"
	fi
	local go_module
	go_module=$(awk '$1 == "module" { print $2; exit }' go.mod)
	if [[ -z "$go_module" ]]; then
		log_error "Unable to determine Go module name from go.mod"
		return 1
	fi

	log_info "Creating folder structure..."
	mkdir -p cmd/api internal/config internal/db internal/handlers internal/models scripts 2>/dev/null

	# Create internal/config/config.go
	cat >internal/config/config.go <<'EOF'
package config

import "os"

type Config struct {
	Port        string
	DatabaseURL string
}

func LoadConfig() Config {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://postgres:postgres@localhost:5432/mydb"
	}
	return Config{
		Port:        port,
		DatabaseURL: dbURL,
	}
}
EOF
	log_success "Created internal/config/config.go"

	# Create main.go based on framework
	if [[ "$framework_choice" == "Gin" ]]; then
		cat >cmd/api/main.go <<EOF
package main

import (
	"fmt"
	"net/http"
	"$go_module/internal/config"
	"$go_module/internal/handlers"
	"github.com/gin-gonic/gin"
)

func main() {
	cfg := config.LoadConfig()
	r := gin.Default()

	r.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"message": "Welcome to Karnel Go (Gin)!",
			"status":  "healthy",
		})
	})

	r.GET("/items", handlers.GetItems)

	fmt.Printf("Server starting on port %s...\n", cfg.Port)
	r.Run(":" + cfg.Port)
}
EOF
	else
		cat >cmd/api/main.go <<EOF
package main

import (
	"fmt"
	"$go_module/internal/config"
	"$go_module/internal/handlers"
	"github.com/gofiber/fiber/v2"
)

func main() {
	cfg := config.LoadConfig()
	app := fiber.New()

	app.Get("/", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"message": "Welcome to Karnel Go (Fiber)!",
			"status":  "healthy",
		})
	})

	app.Get("/items", handlers.GetItems)

	fmt.Printf("Server starting on port %s...\n", cfg.Port)
	app.Listen(":" + cfg.Port)
}
EOF
	fi
	log_success "Created cmd/api/main.go"

	# Create internal/handlers/handlers.go
	cat >internal/handlers/handlers.go <<'EOF'
package handlers

import (
	"net/http"
)

func GetItems(w interface{}) {
	// Abstracted handler returning static list for structure demonstration
}
EOF
	# Fix GetItems signature depending on framework
	if [[ "$framework_choice" == "Gin" ]]; then
		cat >internal/handlers/handlers.go <<'EOF'
package handlers

import (
	"net/http"
	"github.com/gin-gonic/gin"
)

func GetItems(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"items": []map[string]interface{}{
			{"id": 1, "title": "Item 1", "description": "Go Gin boilerplate item"},
		},
	})
}
EOF
	else
		cat >internal/handlers/handlers.go <<'EOF'
package handlers

import (
	"github.com/gofiber/fiber/v2"
)

func GetItems(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{
		"items": []fiber.Map{
			{"id": 1, "title": "Item 1", "description": "Go Fiber boilerplate item"},
		},
	})
}
EOF
	fi
	log_success "Created internal/handlers/handlers.go"

	# Create .env
	if [[ ! -f ".env" ]]; then
		cat >.env <<'EOF'
PORT=8080
DATABASE_URL=postgres://postgres:postgres@localhost:5432/mydb
EOF
		log_success "Created .env"
	fi

	# Create scripts/run.sh
	cat >scripts/run.sh <<'EOF'
#!/usr/bin/env bash
go run cmd/api/main.go
EOF
	chmod +x scripts/run.sh

	# Install dependencies
	log_info "Installing dependencies..."
	if command -v go &>/dev/null; then
		if [[ "$framework_choice" == "Gin" ]]; then
			go get github.com/gin-gonic/gin 2>/dev/null || true
		else
			go get github.com/gofiber/fiber/v2 2>/dev/null || true
		fi
		go mod tidy 2>/dev/null || true
	fi

	# Create Dockerfile
	cat >Dockerfile <<'EOF'
FROM golang:1.20-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /api-server cmd/api/main.go

FROM alpine:latest
WORKDIR /
COPY --from=builder /api-server /api-server
EXPOSE 8080
CMD ["/api-server"]
EOF
	log_success "Created Dockerfile"

	# Create README.md
	cat >README.md <<EOF
# Go ($framework_choice) API

Projeto inicializado via **Karnel** utilizando Arquitetura Limpa.

## Como Executar
1. Instale o Go.
2. Execute o servidor de desenvolvimento:
   \`\`\`bash
   ./scripts/run.sh
   \`\`\`
EOF
	log_success "Created README.md"

	log_success "Go ($framework_choice) project configured!"
	log_info "Run: ./scripts/run.sh"
	echo
}

configure_rust() {
	separator
	box "Configuring Rust Project"
	separator
	echo

	local framework_choice db_choice
	read_select "Select Rust web framework" framework_choice "Axum" "Actix Web"
	read_select "Select database driver" db_choice "SQLx (PostgreSQL)" "Diesel" "None"

	log_info "Initializing Cargo project if needed..."
	if [[ ! -f "Cargo.toml" ]]; then
		cargo init --bin 2>/dev/null
		log_success "Initialized Cargo project"
	fi

	# Append dependencies to Cargo.toml
	if [[ -f "Cargo.toml" ]]; then
		if ! grep -q '^\[dependencies\]' Cargo.toml; then
			printf '\n[dependencies]\n' >> Cargo.toml
		fi
		local dep name spec
		local -a deps=(
			'tokio = { version = "1.0", features = ["full"] }'
			'serde = { version = "1.0", features = ["derive"] }'
			'serde_json = "1.0"'
			'dotenvy = "0.15"'
		)
		if [[ "$framework_choice" == "Axum" ]]; then
			deps+=('axum = "0.7"')
		else
			deps+=('actix-web = "4.0"')
		fi
		if [[ "$db_choice" == "SQLx (PostgreSQL)" ]]; then
			deps+=('sqlx = { version = "0.7", features = ["runtime-tokio", "postgres", "macros"] }')
		fi
		for dep in "${deps[@]}"; do
			name="${dep%% =*}"
			name="${name%%[[:space:]]*}"
			if grep -q "^${name} =" Cargo.toml; then
				log_info "Dependency already present: ${name}"
			else
				sed -i "/^\[dependencies\]/a ${dep}" Cargo.toml
			fi
		done
		log_success "Configured Cargo.toml"
	fi
	local rust_binary
	rust_binary=$(awk -F '"' '/^name[[:space:]]*=/ { print $2; exit }' Cargo.toml)
	if [[ -z "$rust_binary" ]]; then
		log_error "Unable to determine Rust package name from Cargo.toml"
		return 1
	fi

	# Create src/main.rs
	mkdir -p src scripts 2>/dev/null
	if [[ "$framework_choice" == "Axum" ]]; then
		cat >src/main.rs <<'EOF'
use axum::{routing::get, Json, Router};
use serde::Serialize;
use std::net::SocketAddr;

#[derive(Serialize)]
struct Status {
    message: String,
    status: String,
}

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();
    
    let app = Router::new().route("/", get(handler));

    let port = std::env::var("PORT").unwrap_or_else(|_| "3000".to_string());
    let addr_str = format!("127.0.0.1:{}", port);
    let addr: SocketAddr = addr_str.parse().unwrap();
    println!("Listening on {}", addr);
    
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn handler() -> Json<Status> {
    Json(Status {
        message: "Welcome to Karnel Rust (Axum)!".to_string(),
        status: "healthy".to_string(),
    })
}
EOF
	else
		cat >src/main.rs <<'EOF'
use actix_web::{get, App, HttpResponse, HttpServer, Responder};
use serde::Serialize;

#[derive(Serialize)]
struct Status {
    message: String,
    status: String,
}

#[get("/")]
async fn index() -> impl Responder {
    HttpResponse::Ok().json(Status {
        message: "Welcome to Karnel Rust (Actix Web)!".to_string(),
        status: "healthy".to_string(),
    })
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    dotenvy::dotenv().ok();
    let port = std::env::var("PORT").unwrap_or_else(|_| "8080".to_string());
    println!("Server running on 127.0.0.1:{}", port);
    
    HttpServer::new(|| {
        App::new().service(index)
    })
    .bind(format!("127.0.0.1:{}", port))?
    .run()
    .await
}
EOF
	fi
	log_success "Created src/main.rs"

	# Create .env
	if [[ ! -f ".env" ]]; then
		cat >.env <<'EOF'
PORT=3000
DATABASE_URL=postgres://postgres:postgres@localhost:5432/mydb
EOF
		log_success "Created .env"
	fi

	# Create scripts/run.sh
	cat >scripts/run.sh <<'EOF'
#!/usr/bin/env bash
cargo run
EOF
	chmod +x scripts/run.sh

	# Create Dockerfile
	cat >Dockerfile <<EOF
FROM rust:1.70 AS builder
WORKDIR /app
COPY . .
RUN cargo build --release

FROM debian:bullseye-slim
WORKDIR /app
COPY --from=builder /app/target/release/$rust_binary .
EXPOSE 3000
CMD ["./$rust_binary"]
EOF
	log_success "Created Dockerfile"

	# Create README.md
	cat >README.md <<EOF
# Rust ($framework_choice) API

Projeto inicializado via **Karnel** utilizando Rust.

## Como Executar
1. Execute o servidor de desenvolvimento:
   \`\`\`bash
   ./scripts/run.sh
   \`\`\`
EOF
	log_success "Created README.md"

	log_success "Rust ($framework_choice) project configured!"
	log_info "Run: ./scripts/run.sh"
	echo
}

_init_confirm_overwrite() {
	local confirm
	read_confirm "Karnel may overwrite existing project files. Continue?" confirm n
	if [[ "$confirm" != "y" ]]; then
		log_warn "Cancelled"
		return 1
	fi
}

# ===== MAIN =====
init_main() {
	local template="$1"

	case "$template" in
	--help|-h)
		init_help
		return
		;;
	next | nextjs) _init_confirm_overwrite || return 0; configure_next ;;
	react | vite) _init_confirm_overwrite || return 0; configure_react ;;
	nest | nestjs) _init_confirm_overwrite || return 0; configure_nest ;;
	express | exp) _init_confirm_overwrite || return 0; configure_express ;;
	python | fastapi) _init_confirm_overwrite || return 0; configure_python ;;
	go | gin) _init_confirm_overwrite || return 0; configure_go ;;
	rust | axum) _init_confirm_overwrite || return 0; configure_rust ;;
	"")
		local detected
		detected=$(detect_project_type)
		if [[ "$detected" != "unknown" ]]; then
			log_info "Detected project type: $detected"
			echo
			_init_confirm_overwrite || return 0
			case "$detected" in
			next) configure_next ;;
			react) configure_react ;;
			nest) configure_nest ;;
			express) configure_express ;;
			python) configure_python ;;
			go) configure_go ;;
			rust) configure_rust ;;
			esac
		else
			init_help
		fi
		;;
	*)
		log_error "Unknown template: $template"
		init_help
		return 1
		;;
	esac
}

detect_project_type() {
	[[ -f "requirements.txt" ]] && { echo "python"; return; }
	[[ -f "go.mod" ]] && { echo "go"; return; }
	[[ -f "Cargo.toml" ]] && { echo "rust"; return; }
	[[ ! -f "package.json" ]] && { echo "unknown"; return; }
	grep -q "next" package.json 2>/dev/null && { echo "next"; return; }
	grep -q "vite" package.json 2>/dev/null && { echo "react"; return; }
	grep -q "@nestjs" package.json 2>/dev/null && { echo "nest"; return; }
	grep -q "express" package.json 2>/dev/null && { echo "express"; return; }
	echo "unknown"
}
