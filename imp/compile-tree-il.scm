;;  Copyright (C) 2012
;;      "Mu Lei" known as "NalaGinrut" <NalaGinrut@gmail.com>
;;  Ragnarok is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU General Public License as published by
;;  the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.

;;  Ragnarok is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU General Public License for more details.

;;  You should have received a copy of the GNU General Public License
;;  along with this program.  If not, see <http://www.gnu.org/licenses/>.

(define-module (language imp compile-tree-il)
  #:use-module (language tree-il)
  #:use-module (ice-9 receive)
  #:use-module (system base pmatch)
  #:use-module (srfi srfi-1)
  #:export (compile-tree-il))

(define-syntax-rule (-> (type arg ...))
  `(type ,arg ...))

(define empty-lexical-environment
  (make-hash-table))

(define (imp-init)
  #t
  ;; nothing to do yet.
  )

(define (compile-tree-il exp env opts)
  (values
   (parse-tree-il
    (begin (imp-init)
	   (comp exp empty-lexical-environment)))
   env
   env))

(define (location x)
  (and (pair? x)
       (let ((props (source-properties x)))
         (and (not (null? props))
              props))))

(define-syntax-rule (->boolean x)
  (not (equal? x 'false)))
  
;; for emacs:
;; (put 'pmatch/source 'scheme-indent-function 1)

(define-syntax-rule (pmatch/source x clause ...)
  (let ((x x))
    (let ((res (pmatch x
                 clause ...)))
      (let ((loc (location x)))
        (if loc
            (set-source-properties! res (location x))))
      res)))

(define (lookup name env)
  (hash-ref env name))
     
(define (store name value env)
  (hash-set! env name value))

(define (comp src e)
  (let ((l 0));;(location src)))
    (define (let1 what proc)
      (let ((sym (gensym))) 
        (-> (let (list sym) (list sym) (list what)
                 (proc sym)))))
    (define (begin1 what proc)
      (let1 what (lambda (v)
                   (-> (begin (proc v)
                              (-> (lexical v v)))))))
    (pmatch/source src
     (true
      (-> (const #t)))
     (false
      (-> (const #f)))
     ((number ,x)
      (-> (const x)))
     ((variable ,x)
      (lookup x e))
     ((store ,x ,v)
      (store x (comp v e) e))
     ;; FIXME: we need lexical scope
     ((begin ,form)
      (comp form e))
     ((begin . ,forms)
      `(begin ,@(map (lambda (x) (comp x e)) forms)))
     ((+ ,x ,y)
      (-> (apply (-> (primitive '+)) (comp x e) (comp y e))))
     ((- ,x ,y)
      (-> (apply (-> (primitive '-)) (comp x e) (comp y e))))
     ((* ,x ,y)
      (-> (apply (-> (primitive '*)) (comp x e) (comp y e))))
     ((eq ,x ,y)
      (-> (apply (-> (primitive 'eqv?)) (comp x e) (comp y e))))
     ((less-eq ,x ,y)
      (-> (apply (-> (primitive '<=)) (comp x e) (comp y e))))
     ((skip)
      (-> (void)))
     ((if-else ,test ,then ,else)
      (-> (if (->boolean (comp test e))
	      (comp then e)
	      (comp else e))))
     ((if ,test ,then)
      (-> (if (->boolean (comp test e))
	      (comp then e)
	      (const '*unspecified*))))
     ((not ,x)
      (-> (apply (-> (primitive 'not)) (comp x e))))
     ((and ,x ,y)
      (-> (if (->boolean (comp x e))
	      (comp y e)
	      (-> (const #f)))))
     ((or ,x ,y)
      (let1 (comp x e)
	    (lambda (v)
	      (-> (if (->boolean (-> (lexical v v)))
		      (-> (lexical v v))
		      (comp y e))))))
     ((while ,test ,do)
      (-> (while (->boolean (comp test e)) (comp do e))))	    
     )))

