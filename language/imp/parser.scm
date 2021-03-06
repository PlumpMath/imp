;;  Copyright (C) 2012 2013
;;      "Mu Lei" known as "NalaGinrut" <NalaGinrut@gmail.com>
;;  This file is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU General Public License as published by
;;  the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.

;;  This file is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU General Public License for more details.

;;  You should have received a copy of the GNU General Public License
;;  along with this program.  If not, see <http://www.gnu.org/licenses/>.

(define-module (language imp parser)
  #:use-module (language imp utils)
  #:use-module (language imp lexer)
  #:use-module (system base lalr)
  #:export (imp-read))

(define (imp-read port)
  (make-reader make-parser make-imp-tokenizer port))

(define (make-parser)
  (lalr-parser
   (;; punctuation
    semi-colon comma dot lbrace lparen rbrace rparen
    ;; keyword
    if while do skip true false
     ;; literal
    number variable
    (nonassoc: then)
    (nonassoc: else)
    ;; operation
    not assign less-eq eq
    (left: + -)
    (left: *)
    (left: or and))

   (program (stmt) : $1
	    (*eoi*) : *eof-object*)

   (stmt (semi-colon) : '(begin) 
         (Exp semi-colon) : $1)
         	 
   ;; (null-stmt) : $1)

   ;; FIXME: we need recursive blocks
   ;;(block (lbrace stmt-list rbrace) : $2)
   
   ;;(stmt-list (stmt) : $1
   ;;	      (stmt-list stmt) : (if (and (pair? $1) (eq? (car $1) 'begin))
    ;;                                 `(begin ,@(cdr $1) ,$2)
    ;;                                 `(begin ,$1 ,$2)))

   (Exp	(Aexp) : $1
	(Bexp) : $1
	(Cexp) : $1)

   ;; left to right
   ;; TODO: support div
   (Aexp (atom) : $1
	 (Aexp + Aexp) : `(+ ,$1 ,$3)
	 (Aexp - Aexp) : `(- ,$1 ,$3)
	 (Aexp * Aexp) : `(* ,$1 ,$3))

   (atom (number) : `(number ,$1)
	 (variable) : `(variable ,$1))
	 
   (Bexp (bool) : $1
         (lparen Bexp rparen) : $2
	 (Aexp eq Aexp) : `(eq ,$1 ,$3)
	 (Aexp less-eq Aexp) : `(less-eq ,$1 ,$3)
	 (not Bexp) : `(not ,$2)
	 (Bexp and Bexp) : `(and ,$1 ,$3)
	 (Bexp or Bexp) : `(or ,$1 ,$3))

   (Cexp (skip) : `(skip)
         (lbrace Cexp rbrace) : $2
	 (assign-context) : $1
	 (loop-context) : $1
	 (pred-exp) : $1)

   (pred-exp (if-context) : $1)

   (bool (true) : 'true
	 (false) : 'false)

   (assign-context (variable assign Aexp) : `(store ,$1 ,$3))

   (if-context (if lparen Bexp rparen then Cexp) 
	       : `(if ,$3 ,$6)
               (if lparen Bexp rparen then lbrace stmt rbrace) 
               : `(if ,$3 ,$7)
	       (if lparen Bexp rparen then Cexp else Cexp) 
	       : `(if-else ,$3 ,$6 ,$8)
               (if lparen Bexp rparen then lbrace stmt rbrace else lbrace stmt rbrace) 
	       : `(if-else ,$3 ,$7 ,$11))
	         
   (loop-context (while lparen Bexp rparen do Cexp) 
                 : `(while ,$2 ,$4)
                 (while lparen Bexp rparen do lbrace stmt rbrace)
                 : `(while ,$3 ,$7))))
