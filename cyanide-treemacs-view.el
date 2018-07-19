;; This file is part of CyanIDE.
;;
;; CyanIDE is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; CyanIDE is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with CyanIDE.  If not, see <http://www.gnu.org/licenses/>.

(require 'dash)
(require 'treemacs-workspaces)
(require 'treemacs-visuals)
(require 'cyanide-project)
(require 'cyanide-view-simple)

(eval-and-compile
  (require 'cl-lib)
  (require 'treemacs-macros))
(require 'treemacs-structure)
(treemacs-import-functions-from "treemacs-branch-creation"
  treemacs--collapse-root-node
  treemacs--expand-root-node
  treemacs--add-root-element)

(cyanide-view-simple
 :id 'cyanide-treemacs-view
 :teardown-hook '((lambda ()
                    (progn
                      (when (and (bound-and-true-p cyanide-treemacs-window)
                                 (window-live-p cyanide-treemacs-window))
                        (delete-window cyanide-treemacs-window)))))
 :load-hook '((lambda ()
                (progn
                  (call-interactively 'treemacs)
                  (setq cyanide-treemacs-window (selected-window))
                  (set-window-dedicated-p cyanide-treemacs-window t)
                  (cyanide-treemacs-clear-workspace-and-add-current-project)
                  (treemacs-TAB-action)
                  (other-window 1)))))

(defun cyanide-treemacs-workspace-remove-all-projects ()
  (interactive)
  (let ((projects (treemacs-workspace->projects treemacs-current-workspace))
        (pos nil)
        (retval nil))
    (dolist (proj projects retval)
      (progn
        (setq pos (treemacs-project->position proj))
        (goto-char pos)
        (treemacs-remove-project)))))

;; TODO make this non-interactive. I don't want the call to read-string in
;; treemacs-add-project-at. Maybe use advice?
(defun cyanide-treemacs-add-current-project-to-workspace ()
  (cyanide-treemacs-add-project (cyanide-get-current-project)))

(defun cyanide-treemacs-clear-workspace-and-add-current-project ()
  (interactive)
  (cyanide-treemacs-workspace-remove-all-projects)
  (cyanide-treemacs-add-current-project-to-workspace))

(cl-defmethod cyanide-treemacs-add-project ((proj cyanide-project))
  "This code is from treemacs, adapted to infer project name from CyanIDE"
  (let ((path (cyanide-project-oref :path)))
    (--if-let (treemacs--find-project-for-path path)
        (progn
          (goto-char (treemacs-project->position it))
          (treemacs-pulse-on-success
              (format "Project for %s already exists."
                      (propertize path 'face 'font-lock-string-face))))
      (-let*- [(name (cyanide-project-oref :display-name))
               (project (make-treemacs-project :name name :path path))
               (empty-workspace? (-> treemacs-current-workspace (treemacs-workspace->projects) (null)))]
        (treemacs--add-project-to-current-workspace project)
        (treemacs-run-in-every-buffer
         (treemacs-with-writable-buffer
          (if empty-workspace?
              (progn
                (goto-char (point-min))
                (treemacs--reset-index))
            (goto-char (point-max))
            (if (treemacs-current-button)
                (insert "\n\n")
              (insert "\n")))
          (treemacs--add-root-element project)
          (treemacs--insert-shadow-node (make-treemacs-shadow-node
                                         :key path :position (treemacs-project->position project)))))
        (treemacs-pulse-on-success "Added project %s to the workspace."
          (propertize name 'face 'font-lock-type-face))))))

(provide 'cyanide-treemacs-view)
