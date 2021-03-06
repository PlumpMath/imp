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

(define-module (language imp lexer)
  #:use-module (language imp utils)
  #:use-module (system base lalr)
  #:use-module (ice-9 receive)
  #:use-module (ice-9 rdelim)
  #:use-module (srfi srfi-1)
  #:export (make-imp-tokenizer))

(define *operations* "~+-*=<^|:")

(define *delimiters* (string-append " ,.\n;\t()[]{}" *operations*))

(define *invalid-char* " ^|*(){}[]`!@#$%&\\'\"?></")
  
(define *keywords*
  '(("if" . if)
    ("then" . then)
    ("else" . else)
    ("while" . while)
    ("do" . do)
    ("skip" . skip)
    ("true" . true)
    ("false" . false)))

(define *op-tokens*
  '(("+" . +)
    ("-" . -)
    ("*" . *)
    ("=" . eq)
    ("<=" . less-eq)
    (":=" . assign)
    ("|" . or)
    ("^" . and)
    ("~" . not)))

(define *punctuations*
  '((";" . semi-colon)
    ("," . comma)
    ("." . dot)
    ("{" . lbrace)
    ("}" . rbrace)
    ("(" . lparen)
    (")" . rparen)))

(define *charset-not-in-var*
  (string->char-set (string-append *invalid-char* *delimiters*)))

;; in Simple IMP, we only have bin/oct/hex number
(define is-number?
  (lambda (c)
    (char-set-contains? char-set:hex-digit c)))

(define-syntax-rule (checker what c)
  (string-contains what (string c)))

(define is-delimiter?
  (lambda (c)
    (checker *delimiters* c)))

(define is-op?
  (lambda (c)
    (and (not (eof-object? c))
	 (checker *operations* c))))

(define (unget-char1 c port)
  (and (char? c) (unread-char c port)))
 
(define (port-skip port n)
  (and (> n 0) (port-skip port (1- n))))
	 
(define read-word
  (lambda (port)
    (read-delimited *delimiters* port 'peek)))
    
(define next-is-keyword?
  (lambda (port)
    (let* ((word (read-word port))
	   (keyword (assoc-ref *keywords* word)))
      (cond
       (keyword keyword)
       (else
        (unread-string word port)
        #f)))))

(define* (get-number lst #:optional (base 10))
  (string->number (apply string lst) base))

(define come-back-baby
  (lambda (port . babies)
    (for-each (lambda (c)
		(unget-char1 c port))
	      babies)))

(define is-immediate-number?
  (lambda (c)
    (let ((i (char->integer c)))
      (and (>= i #x30) (<= i #x39)))))

(define (is-valid-number-header? port)
  (let ((c (peek-char port)))
    (cond
     ((eof-object? c) #f)
     ((char=? c #\#) #t)
     (else #f))))

(define next-is-number?
  (lambda (port)
    (cond
     ((is-immediate-number? (peek-char port))
      10) ;; decimal situation
     ((is-valid-number-header? port)
      (let ((c0 (peek-char port)))
        (if (char=? c0 #\#) ;; #x #o #d #b
            (let* ((c0 (read-char port))
                   (c1 (read-char port))
                   (c2 (peek-char port)))
              (if (is-number? c2)
                  (case c1
                    ((#\x) 16)
                    ((#\d) 10)
                    ((#\o) 8)
                    ((#\b) 2)
                    (else (error "invalid number base!" (string c0 c1))))
                  (begin
                    (come-back-baby port c1 c0)
                    #f)))
            (if (is-number? c0)
                10
                #f))))
     (else #f)))) ;; not a number
	    
(define read-number
  (lambda (port base)
    (let* ((str (read-word port))
           (num (string->number str base)))
      (values 'number num))))

(define next-is-operation?
  (lambda (port)
    (if (not (checker *operations* (peek-char port)))
        #f ; not an operation
        (let lp((c (read-char port)) (op '()))
          (cond
           ((checker *operations* c)
            (lp (read-char port) (cons c op)))
           (else
            (unget-char1 c port)
            (assoc-ref *op-tokens* (apply string (reverse op)))))))))

(define check-var
  (lambda (var)
    (cond
     ((or (string-null? var)
          (is-immediate-number? (string-ref var 0)))
      #f)
     (else
      (not
       (string-any (lambda (c)
                     (and (char-set-contains? *charset-not-in-var* c) c))
                   var))))))
	 
(define next-is-var?
  (lambda (port)
    (let ((word (read-word port)))
      (cond
       ((check-var word) 
        (string->symbol word))
       (else
        (unread-string word port)
        #f)))))
    
(define next-is-comment?
  (lambda (port)
    (let* ((c0 (read-char port))
	   (c1 (read-char port)))
      (cond
       ((or (eof-object? c0) (eof-object? c1))
        (come-back-baby port c1 c0)
        #f)
       ((and (char=? #\/ c0) (char=? #\/ c1))
	#t)
       (else
	(come-back-baby port c1 c0)
	#f)))))

(define skip-comment
  (lambda (port)
    (read-delimited "\n" port)))

(define next-is-punctuation?
  (lambda (port)
    (let* ((c (read-char port))
	   (punc (assoc-ref *punctuations* (string c))))
      (cond
       (punc punc)
       (else
	(unget-char1 c port)
	#f)))))
	  
(define next-token
  (lambda (port)
    (let ((c (peek-char port)))
      (cond
       ((is-whitespace? c)
        (read-char port)
        (next-token port)) ; skip whitespace
       (else
        (cond
         ((eof-object? c) '*eoi*)
         ((next-is-comment? port) 
          (skip-comment port) ;; only line comment
          (next-token port))
         ((next-is-number? port)
          => (lambda (base)
               (receive (type ret) (read-number port base) (return port type ret))))
         ((next-is-keyword? port) 
          => (lambda (keyword)
               (return port keyword #f)))
         ((next-is-var? port)
          => (lambda (var)
               (return port 'variable var)))
         ((next-is-operation? port) 
          => (lambda (op)
               (return port op #f)))
         ((next-is-punctuation? port)
          => (lambda (punc)
               (return port punc #f)))
         (else (error "invalid token!" c))))))))

(define imp-tokenizer
  (lambda (port)
    (let lp ((out '()))
      (let ((tok (next-token port)))
 	(if (eq? tok '*eoi*)
 	    (reverse! out)
 	    (lp (cons tok out)))))))

(define (make-imp-tokenizer port)
 (let ((div? #f) ; TODO: add div support
       (eoi? #f)
       (stack '()))
   (lambda ()
     (if eoi?
         '*eoi*
         (let ((tok (next-token port)))
           (case (if (lexical-token? tok) (lexical-token-category tok) tok)
             ((lparen)
              (set! stack (cons tok stack)))
             ((rparen)
              (if (and (pair? stack)
                       (eq? (lexical-token-category (car stack)) 'lparen))
                  (set! stack (cdr stack))
                  (lex-error "unexpected right parenthesis"
                                (lexical-token-source tok)
                                #f)))
             ((lbracket)
              (set! stack (cons tok stack)))
             ((rbracket)
              (if (and (pair? stack)
                       (eq? (lexical-token-category (car stack)) 'lbracket))
                  (set! stack (cdr stack))
                  (lex-error "unexpected right bracket"
                                (lexical-token-source tok)
                                #f)))
             ((lbrace)
              (set! stack (cons tok stack)))
             ((rbrace)
              (if (and (pair? stack)
                       (eq? (lexical-token-category (car stack)) 'lbrace))
                  (set! stack (cdr stack))
                  (lex-error "unexpected right brace"
                                (lexical-token-source tok)
                                #f)))
             ;; NOTE: this checker promised the last semi-colon before eof will return '*eoi* directly,
             ;;       or we have to press EOF (C-d) to end the input.
             ;;       BUT I WONDER IF THERE'S A BETTER WAY FOR THIS!
             ((semi-colon)
              (set! eoi? (null? stack))))

           (set! div? (and (lexical-token? tok)
                           (let ((cat (lexical-token-category tok)))
                             (or (eq? cat 'variable)
                                 (eq? cat 'number)
                                 (eq? cat 'string)))))
           tok)))))
